import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../models/habits.dart';
import '../utils/format.dart';

/// Recordatorios del sistema (agua y evaluación corporal).
/// Se programan como avisos sueltos en hora local para los próximos días y se
/// vuelven a calcular cada vez que se abre la app o cambia algo relevante.
abstract class Reminders {
  Future<void> scheduleWater(List<DateTime> times);
  Future<void> scheduleEvaluation(DateTime? at);
  Future<void> scheduleWorkout(List<WorkoutReminder> items);

  /// Aviso unos días antes de la próxima regla estimada (null = ninguno).
  Future<void> schedulePeriod(DateTime? at, {required int daysBefore});
}

class NoopReminders implements Reminders {
  @override
  Future<void> scheduleWater(List<DateTime> times) async {}
  @override
  Future<void> scheduleEvaluation(DateTime? at) async {}
  @override
  Future<void> scheduleWorkout(List<WorkoutReminder> items) async {}
  @override
  Future<void> schedulePeriod(DateTime? at, {required int daysBefore}) async {}
}

/// 9:00 de [daysBefore] días antes de [nextStart], si aún no ha pasado.
DateTime? periodReminderAt({required DateTime? nextStart, required DateTime now, int daysBefore = 2}) {
  if (nextStart == null) return null;
  final at = DateTime(nextStart.year, nextStart.month, nextStart.day - daysBefore, 9);
  return at.isAfter(now) ? at : null;
}

/// Horas en las que recordar beber agua en los próximos [days] días.
/// Hoy se omite si ya se cumplió la meta; nunca se programan horas pasadas.
List<DateTime> waterReminderTimes({
  required DateTime now,
  required HabitsSettings settings,
  required bool goalMetToday,
  int days = 3,
}) {
  if (!settings.waterReminders) return const [];
  final out = <DateTime>[];
  final today = dateOnly(now);
  for (var d = 0; d < days; d++) {
    if (d == 0 && goalMetToday) continue;
    final day = DateTime(today.year, today.month, today.day + d);
    for (final h in settings.reminderHours) {
      final t = DateTime(day.year, day.month, day.day, h);
      if (t.isAfter(now)) out.add(t);
    }
  }
  return out;
}

/// Aviso de evaluación a las 10:00 del día que toca. Si ya pasó, a las 10:00 del día siguiente (una sola vez).
DateTime? evaluationReminderAt({required DateTime? nextEvaluation, required DateTime now, required bool enabled}) {
  if (!enabled || nextEvaluation == null) return null;
  var at = DateTime(nextEvaluation.year, nextEvaluation.month, nextEvaluation.day, 10);
  if (!at.isAfter(now)) {
    final t = dateOnly(now);
    at = DateTime(t.year, t.month, t.day + 1, 10);
  }
  return at;
}

class WorkoutReminder {
  const WorkoutReminder({required this.at, required this.title, required this.body});
  final DateTime at;
  final String title;
  final String body;
}

const _workoutMessages = [
  '¡Tú puedes! Solo es empezar 💪',
  'Ropa cómoda y a moverte ✨',
  'Tu yo de mañana te lo va a agradecer 💜',
  'Un entrenamiento más para tu racha 🔥',
];

/// Avisos "Es hora de entrenar" en los próximos [days] días que tienen entrenamiento.
/// [dayTitles]: título del día por día de la semana (1 = lunes), solo días de entrenamiento.
/// Hoy se omite si ya entrenaste o si la hora ya pasó.
List<WorkoutReminder> workoutReminders({
  required DateTime now,
  required HabitsSettings settings,
  required Map<int, String> dayTitles,
  required bool trainedToday,
  String petName = '',
  int days = 7,
}) {
  if (!settings.workoutReminder || dayTitles.isEmpty) return const [];
  final out = <WorkoutReminder>[];
  final today = dateOnly(now);
  for (var d = 0; d < days; d++) {
    if (d == 0 && trainedToday) continue;
    final day = DateTime(today.year, today.month, today.day + d);
    final title = dayTitles[day.weekday];
    if (title == null) continue;
    final at = DateTime(day.year, day.month, day.day, settings.workoutReminderHour, settings.workoutReminderMinute);
    if (!at.isAfter(now)) continue;
    final cheer = _workoutMessages[day.day % _workoutMessages.length];
    out.add(WorkoutReminder(
      at: at,
      title: 'Es hora de entrenar 💪',
      body: 'Hoy toca: $title. ${petName.trim().isEmpty ? cheer : '${petName.trim()} te espera. $cheer'}',
    ));
  }
  return out;
}

class LocalReminders implements Reminders {
  final _plugin = FlutterLocalNotificationsPlugin(); // instancia única, ya inicializada en rest_alarm.dart

  static const _waterBase = 2000;
  static const _waterMax = 60;
  static const _evaluationId = 3001;
  static const _periodId = 3002;
  static const _workoutBase = 4000;
  static const _workoutMax = 14;

  static const _waterMessages = [
    'Un vaso de agua y seguimos 💧',
    '¿Has bebido agua? Tu cuerpo lo agradece.',
    'Pausa de hidratación 💧',
    'Un sorbo ahora y te sientes mejor.',
  ];

  NotificationDetails _details(String channel, String name, String description) => NotificationDetails(
        android: AndroidNotificationDetails(
          channel,
          name,
          channelDescription: description,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          icon: 'ic_stat_fitmakyp',
          color: const Color(0xFF7041B8),
        ),
        iOS: const DarwinNotificationDetails(),
      );

  @override
  Future<void> scheduleWater(List<DateTime> times) async {
    if (kIsWeb) return;
    try {
      for (var i = 0; i < _waterMax; i++) {
        await _plugin.cancel(id: _waterBase + i);
      }
      for (final (i, t) in times.take(_waterMax).indexed) {
        await _plugin.zonedSchedule(
          id: _waterBase + i,
          title: 'Hora de beber agua',
          body: _waterMessages[i % _waterMessages.length],
          scheduledDate: tz.TZDateTime.from(t.toUtc(), tz.UTC),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          notificationDetails: _details('water', 'Recordatorios de agua', 'Te recuerda beber agua durante el día'),
        );
      }
    } catch (e) {
      debugPrint('Recordatorios de agua: $e');
    }
  }

  @override
  Future<void> scheduleEvaluation(DateTime? at) async {
    if (kIsWeb) return;
    try {
      await _plugin.cancel(id: _evaluationId);
      if (at == null) return;
      await _plugin.zonedSchedule(
        id: _evaluationId,
        title: 'Hoy toca tu evaluación',
        body: 'Peso, medidas y, si quieres, fotos. Solo te lleva unos minutos.',
        scheduledDate: tz.TZDateTime.from(at.toUtc(), tz.UTC),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        notificationDetails: _details('evaluation', 'Evaluación corporal', 'Aviso cuando toca registrar tu progreso'),
      );
    } catch (e) {
      debugPrint('Recordatorio de evaluación: $e');
    }
  }

  @override
  Future<void> scheduleWorkout(List<WorkoutReminder> items) async {
    if (kIsWeb) return;
    try {
      for (var i = 0; i < _workoutMax; i++) {
        await _plugin.cancel(id: _workoutBase + i);
      }
      for (final (i, r) in items.take(_workoutMax).indexed) {
        await _plugin.zonedSchedule(
          id: _workoutBase + i,
          title: r.title,
          body: r.body,
          scheduledDate: tz.TZDateTime.from(r.at.toUtc(), tz.UTC),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          notificationDetails: _details('workout', 'Hora de entrenar', 'Te avisa los días que toca entrenar'),
        );
      }
    } catch (e) {
      debugPrint('Recordatorio de entreno: $e');
    }
  }

  @override
  Future<void> schedulePeriod(DateTime? at, {required int daysBefore}) async {
    if (kIsWeb) return;
    try {
      await _plugin.cancel(id: _periodId);
      if (at == null) return;
      await _plugin.zonedSchedule(
        id: _periodId,
        title: 'Tu regla podría llegar en $daysBefore días 🌸',
        body: 'Ten a mano lo que necesites. Si te notas con menos energía, un entreno más suave también suma.',
        scheduledDate: tz.TZDateTime.from(at.toUtc(), tz.UTC),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        notificationDetails: _details('cycle', 'Aviso del ciclo', 'Te avisa antes de la próxima regla estimada'),
      );
    } catch (e) {
      debugPrint('Aviso del ciclo: $e');
    }
  }
}
