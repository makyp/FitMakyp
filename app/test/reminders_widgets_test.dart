import 'package:fitmakyp/core/data/seed_plan.dart';
import 'package:fitmakyp/core/models/habits.dart';
import 'package:fitmakyp/core/notifications/reminders.dart';
import 'package:fitmakyp/features/home_widgets/home_widget_sync.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('aviso "Es hora de entrenar"', () {
    const s = HabitsSettings(workoutReminderHour: 18, workoutReminderMinute: 30);
    // 10 nov 2026 es martes.
    final now = DateTime(2026, 11, 10, 12);
    const days = {1: 'Piernas', 2: 'Glúteos', 4: 'Tren superior'};

    test('solo días con entreno, a la hora elegida', () {
      final r = workoutReminders(now: now, settings: s, dayTitles: days, trainedToday: false, petName: 'Luna');
      expect(r.map((x) => x.at.weekday), [2, 4, 1]);
      expect(r.first.at, DateTime(2026, 11, 10, 18, 30));
      expect(r.first.title, contains('Es hora de entrenar'));
      expect(r.first.body, contains('Hoy toca: Glúteos'));
      expect(r.first.body, contains('Luna'));
    });

    test('hoy no avisa si ya entrenaste o si la hora pasó', () {
      expect(workoutReminders(now: now, settings: s, dayTitles: days, trainedToday: true).first.at.weekday, 4);
      final late = DateTime(2026, 11, 10, 19);
      expect(workoutReminders(now: late, settings: s, dayTitles: days, trainedToday: false).first.at.weekday, 4);
    });

    test('desactivado o sin días de entreno: nada', () {
      expect(workoutReminders(now: now, settings: s.copyWith(workoutReminder: false), dayTitles: days, trainedToday: false),
          isEmpty);
      expect(workoutReminders(now: now, settings: s, dayTitles: const {}, trainedToday: false), isEmpty);
    });

    test('el ajuste se guarda', () {
      final j = HabitsSettings.fromJson(s.copyWith(workoutReminder: false).toJson());
      expect(j.workoutReminder, isFalse);
      expect(j.workoutReminderHour, 18);
      expect(j.workoutReminderMinute, 30);
      expect(HabitsSettings.fromJson(const {}).workoutReminder, isTrue);
    });
  });

  test('datos de los widgets: toda la semana y el estado de hoy', () {
    final now = DateTime(2026, 11, 10, 9);
    final plan = buildSeedPlan();
    final d = homeWidgetData(
      now: now,
      plan: plan,
      trainedDates: {DateTime(2026, 11, 8, 18), DateTime(2026, 11, 10, 7)},
      sessionInProgress: false,
      waterGlasses: 3,
      waterGoal: 8,
      streak: 4,
      bestStreak: 9,
      petName: '  ',
      level: 2,
    );
    expect(d['fm_trained_date'], '2026-11-10');
    expect(d['fm_water_date'], '2026-11-10');
    expect(d['fm_water_glasses'], '3');
    expect(d['fm_streak'], '4');
    expect(d['fm_pet_name'], 'Tu mascota');
    for (var w = 1; w <= 7; w++) {
      final day = plan.dayForWeekday(w);
      expect(d['fm_day_title_$w'], isNotEmpty);
      expect(d['fm_day_info_$w']!.isNotEmpty, day != null && day.isTraining && day.activeExercises.isNotEmpty);
    }
    expect(d.values.where((v) => v.contains('ejercicio')), isNotEmpty);
  });
}
