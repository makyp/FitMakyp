/// Fuerza: peso y repeticiones por serie, récords por ejercicio y sugerencia de progresión.
/// Lógica pura.
library;

import '../../../core/models/exercise.dart';
import '../../../core/models/session.dart';

/// Formato de kilos: "8 kg", "7,5 kg".
String formatKg(double kg) =>
    '${kg == kg.roundToDouble() ? kg.round() : kg.toStringAsFixed(1).replaceAll('.', ',')} kg';

/// Serie hecha con sus datos (reps se completa con el objetivo si no se anotó).
class SetPerf {
  const SetPerf({required this.reps, this.weight, required this.at, required this.sessionId});
  final int reps;
  final double? weight;
  final DateTime at;
  final String sessionId;

  /// 1RM estimado (fórmula de Epley). Solo con peso.
  double? get e1rm => weight == null || weight! <= 0 ? null : weight! * (1 + reps / 30);
}

List<SetPerf> _perfs(WorkoutSession s, SessionExercise e) => [
      for (final x in e.sets)
        if (x.result == SetResult.completed || x.repsDone != null)
          SetPerf(
            reps: x.repsDone ?? (e.target.isTime ? 0 : e.target.min),
            weight: x.weightKg,
            at: x.finishedAt,
            sessionId: s.id,
          ),
    ];

/// Series de un ejercicio en una sesión.
List<SetPerf> setsIn(WorkoutSession s, String exerciseId) => [
      for (final e in s.exercises)
        if (e.exerciseId == exerciseId) ..._perfs(s, e),
    ];

/// Última sesión (anterior a [before], si se indica) en la que se hizo el ejercicio, con sus series.
(WorkoutSession, List<SetPerf>)? lastPerformance(
  List<WorkoutSession> sessions,
  String exerciseId, {
  String? excludeSessionId,
}) {
  final sorted = [...sessions]..sort((a, b) => b.startedAt.compareTo(a.startedAt));
  for (final s in sorted) {
    if (s.id == excludeSessionId) continue;
    final sets = setsIn(s, exerciseId);
    if (sets.isNotEmpty) return (s, sets);
  }
  return null;
}

/// Resumen corto de unas series: "3 × 12 · 8 kg" o "12, 12, 10 reps · 6-8 kg".
String describeSets(List<SetPerf> sets, {bool isTime = false}) {
  if (sets.isEmpty) return '';
  final weights = sets.map((s) => s.weight).nonNulls.toSet();
  final w = weights.isEmpty
      ? ''
      : weights.length == 1
          ? ' · ${formatKg(weights.first)}'
          : ' · ${formatKg(weights.reduce((a, b) => a < b ? a : b)).replaceAll(' kg', '')}-${formatKg(weights.reduce((a, b) => a > b ? a : b))}';
  if (isTime) return '${sets.length} ${sets.length == 1 ? 'serie' : 'series'}$w';
  final reps = sets.map((s) => s.reps).toSet();
  final r = reps.length == 1 ? '${sets.length} × ${reps.first}' : '${sets.map((s) => s.reps).join(', ')} reps';
  return '$r$w';
}

/// Incremento recomendado según el peso actual (mancuernas: saltos pequeños).
double weightStep(double w) => w < 10 ? 1 : (w < 30 ? 2 : 2.5);

class ProgressionHint {
  const ProgressionHint({this.weight, required this.reps, required this.message, this.increase = false});

  /// Peso y reps sugeridos para la próxima serie.
  final double? weight;
  final int reps;
  final String message;

  /// true si la sugerencia es subir (peso o reps).
  final bool increase;
}

/// Sugerencia de doble progresión: si la última vez se completaron todas las series llegando al tope
/// del rango de reps, se sube un poco el peso (o las reps si es sin peso). Si no, se repite.
ProgressionHint? suggestNext(List<SetPerf>? last, SetTarget target, int plannedSets) {
  if (target.isTime) return null;
  final top = target.max ?? target.min;
  if (last == null || last.isEmpty) {
    return ProgressionHint(reps: top, message: 'Primera vez: anota las reps que logres (y el peso, si usas). La próxima vez te diré cómo progresar.');
  }
  final weights = last.map((s) => s.weight).nonNulls;
  final w = weights.isEmpty ? null : weights.reduce((a, b) => a > b ? a : b);
  final atTop = last.where((s) => s.weight == w).toList();
  final allDone = atTop.length >= plannedSets && atTop.every((s) => s.reps >= top);
  if (allDone) {
    if (w == null || w <= 0) {
      return ProgressionHint(
        reps: top + 2,
        increase: true,
        message: '¡Completaste todo! Prueba con ${top + 2} reps o añade un poco de peso.',
      );
    }
    final next = w + weightStep(w);
    return ProgressionHint(
      weight: next,
      reps: target.min,
      increase: true,
      message: '¡Lo lograste la última vez! Prueba con ${formatKg(next)} y ${target.min} reps.',
    );
  }
  final best = atTop.isEmpty ? top : atTop.map((s) => s.reps).reduce((a, b) => a > b ? a : b);
  return ProgressionHint(
    weight: w,
    reps: best < top ? best + 1 : top,
    message: w == null
        ? 'Intenta llegar a $top reps en todas las series.'
        : 'Repite ${formatKg(w)} e intenta llegar a $top reps en todas las series.',
  );
}

/// Récords de un ejercicio.
class ExerciseRecords {
  ExerciseRecords(this.exerciseId);
  final String exerciseId;
  String name = '';
  SetPerf? heaviest;
  SetPerf? bestE1rm;
  SetPerf? mostReps;
  int sessions = 0;
  DateTime? last;

  /// Peso máximo por sesión, para la gráfica.
  final List<(DateTime, double)> weightSeries = [];

  bool get hasWeight => heaviest != null;
}

ExerciseRecords exerciseRecords(List<WorkoutSession> sessions, String exerciseId) {
  final r = ExerciseRecords(exerciseId);
  final sorted = [...sessions]..sort((a, b) => a.startedAt.compareTo(b.startedAt));
  for (final s in sorted) {
    final sets = setsIn(s, exerciseId);
    if (sets.isEmpty) continue;
    r.name = s.exercises.firstWhere((e) => e.exerciseId == exerciseId).name;
    r.sessions++;
    r.last = s.startedAt;
    double? maxW;
    for (final x in sets) {
      final w = x.weight;
      if (w != null && w > 0) {
        if (r.heaviest == null || w > r.heaviest!.weight! || (w == r.heaviest!.weight! && x.reps > r.heaviest!.reps)) {
          r.heaviest = x;
        }
        if (r.bestE1rm == null || x.e1rm! > r.bestE1rm!.e1rm!) r.bestE1rm = x;
        if (maxW == null || w > maxW) maxW = w;
      }
      if (r.mostReps == null || x.reps > r.mostReps!.reps) r.mostReps = x;
    }
    if (maxW != null) r.weightSeries.add((s.startedAt, maxW));
  }
  return r;
}

/// Récords de todos los ejercicios hechos (más recientes primero).
List<ExerciseRecords> allRecords(List<WorkoutSession> sessions) {
  final ids = {for (final s in sessions) for (final e in s.exercises) if (e.sets.isNotEmpty) e.exerciseId};
  final out = [for (final id in ids) exerciseRecords(sessions, id)]..removeWhere((r) => r.sessions == 0);
  out.sort((a, b) => b.last!.compareTo(a.last!));
  return out;
}

class NewRecord {
  const NewRecord(this.exerciseName, this.text);
  final String exerciseName;
  final String text;
}

/// Récords batidos en [session] respecto a las sesiones anteriores (la primera vez no cuenta).
List<NewRecord> newRecordsIn(WorkoutSession session, List<WorkoutSession> history) {
  final before = history.where((s) => s.id != session.id && s.startedAt.isBefore(session.startedAt)).toList();
  final out = <NewRecord>[];
  final seen = <String>{};
  for (final e in session.exercises) {
    if (!seen.add(e.exerciseId) || e.target.isTime) continue;
    final now = setsIn(session, e.exerciseId);
    if (now.isEmpty) continue;
    final prev = exerciseRecords(before, e.exerciseId);
    if (prev.sessions == 0) continue;
    final maxW = now.map((s) => s.weight ?? 0).reduce((a, b) => a > b ? a : b);
    if (maxW > 0 && prev.heaviest != null && maxW > prev.heaviest!.weight!) {
      out.add(NewRecord(e.name, 'Nuevo peso máximo: ${formatKg(maxW)}'));
      continue;
    }
    final maxReps = now.map((s) => s.reps).reduce((a, b) => a > b ? a : b);
    final noWeight = now.every((s) => s.weight == null) && prev.heaviest == null;
    if (noWeight && prev.mostReps != null && maxReps > prev.mostReps!.reps) {
      out.add(NewRecord(e.name, 'Más repeticiones que nunca: $maxReps'));
    }
  }
  return out;
}
