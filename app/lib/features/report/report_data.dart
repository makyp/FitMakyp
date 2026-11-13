/// Datos del reporte para el entrenador. Lógica pura: se prueba sin generar el PDF.
library;

import '../../core/models/body.dart';
import '../../core/models/exercise.dart';
import '../../core/models/session.dart';
import '../../core/utils/format.dart';
import '../evolution/domain/muscle_map.dart';
import '../workout/domain/strength.dart';

enum ReportPeriod {
  mes('Último mes', '1 mes', 30),
  trimestre('Últimos 3 meses', '3 meses', 90),
  todo('Desde el inicio', 'Todo', null);

  const ReportPeriod(this.label, this.short, this.days);
  final String label;

  /// Etiqueta corta para el selector.
  final String short;
  final int? days;
}

class ReportWorkout {
  const ReportWorkout({
    required this.date,
    required this.title,
    required this.sets,
    required this.planned,
    required this.minutes,
    this.warmup,
    this.cooldown,
  });
  final DateTime date;
  final String title;
  final int sets;
  final int planned;
  final int minutes;
  final String? warmup;
  final String? cooldown;
}

class ReportStrength {
  const ReportStrength({required this.name, required this.best, this.previous, this.e1rm, required this.sessions});
  final String name;

  /// Mayor peso del periodo y del periodo anterior de la misma duración.
  final double best;
  final double? previous;
  final double? e1rm;
  final int sessions;
}

class ReportMeasure {
  const ReportMeasure({required this.measure, required this.start, required this.end, required this.startDate});
  final Measure measure;
  final double start;
  final double end;
  final DateTime startDate;
  double get change => end - start;
}

class ReportData {
  const ReportData({
    required this.name,
    required this.from,
    required this.to,
    required this.period,
    required this.workouts,
    required this.plannedDays,
    required this.muscleSets,
    required this.weeks,
    required this.strength,
    required this.measures,
    required this.moodAvg,
    required this.energyAvg,
    required this.sleepAvg,
    required this.checkins,
    required this.currentStreak,
    required this.bestStreak,
    this.notes = '',
  });

  final String name;
  final DateTime from;
  final DateTime to;
  final ReportPeriod period;
  final List<ReportWorkout> workouts;

  /// Días con entrenamiento programado en el periodo (para la constancia).
  final int plannedDays;
  final Map<MuscleGroup, double> muscleSets;
  final double weeks;
  final List<ReportStrength> strength;
  final List<ReportMeasure> measures;
  final double? moodAvg;
  final double? energyAvg;
  final double? sleepAvg;
  final int checkins;
  final int currentStreak;
  final int bestStreak;
  final String notes;

  int get totalSets => workouts.fold(0, (a, w) => a + w.sets);
  int get totalMinutes => workouts.fold(0, (a, w) => a + w.minutes);
  int get trainedDays => {for (final w in workouts) dateOnly(w.date)}.length;
  int get warmups => workouts.where((w) => w.warmup == 'done' || w.warmup == 'alreadyDone').length;
  int get cooldowns => workouts.where((w) => w.cooldown == 'done' || w.cooldown == 'alreadyDone').length;

  /// Constancia: días entrenados / días programados (máx. 100 %).
  int? get adherencePct => plannedDays == 0 ? null : (trainedDays * 100 / plannedDays).round().clamp(0, 100);
}

double? _avg(Iterable<int> xs) => xs.isEmpty ? null : xs.reduce((a, b) => a + b) / xs.length;

ReportData buildReportData({
  required String name,
  required ReportPeriod period,
  required DateTime now,
  required List<WorkoutSession> sessions,
  required Exercise? Function(String id) exerciseById,
  required Set<int> trainingWeekdays,
  required List<ProgressRecord> records,
  required List<DailyCheckin> checkins,
  required int currentStreak,
  required int bestStreak,
  String notes = '',
}) {
  final done = sessions.where((s) => s.completedSets > 0).toList()..sort((a, b) => a.startedAt.compareTo(b.startedAt));
  final today = dateOnly(now);
  final firstEver = done.isEmpty ? today : dateOnly(done.first.startedAt);
  final from = period.days == null ? firstEver : today.subtract(Duration(days: period.days! - 1));
  final inPeriod = done.where((s) => !dateOnly(s.startedAt).isBefore(from)).toList();
  final days = today.difference(from).inDays + 1;

  // Constancia: solo desde que empezaste a entrenar con la app (si fue dentro del periodo).
  final countFrom = firstEver.isAfter(from) ? firstEver : from;
  var planned = 0;
  for (var d = countFrom; !d.isAfter(today); d = DateTime(d.year, d.month, d.day + 1)) {
    if (trainingWeekdays.contains(d.weekday)) planned++;
  }

  final map = trainingMap(inPeriod, exerciseById, TrainingPeriod.todo, now, days: days);
  final muscleSets = {
    for (final m in MuscleGroup.values)
      if (map.setsOf(m) > 0) m: map.setsOf(m),
  };

  // Fuerza: ejercicios con peso en el periodo, comparados con el periodo anterior de igual duración.
  final prevFrom = from.subtract(Duration(days: days));
  final prev = done.where((s) => !dateOnly(s.startedAt).isBefore(prevFrom) && dateOnly(s.startedAt).isBefore(from)).toList();
  final ids = {for (final s in inPeriod) for (final e in s.exercises) e.exerciseId};
  final strength = <ReportStrength>[];
  for (final id in ids) {
    final r = exerciseRecords(inPeriod, id);
    if (r.heaviest == null) continue;
    final p = exerciseRecords(prev, id);
    strength.add(ReportStrength(
      name: r.name,
      best: r.heaviest!.weight!,
      previous: p.heaviest?.weight,
      e1rm: r.bestE1rm?.e1rm,
      sessions: r.sessions,
    ));
  }
  strength.sort((a, b) => a.name.compareTo(b.name));

  // Medidas: último valor antes del periodo (o el primero dentro) frente al último.
  final recs = [...records]..sort((a, b) => a.date.compareTo(b.date));
  final measures = <ReportMeasure>[];
  for (final m in Measure.values) {
    final withM = recs.where((r) => r.values[m] != null).toList();
    if (withM.isEmpty) continue;
    final before = withM.where((r) => dateOnly(r.date).isBefore(from)).toList();
    final start = before.isNotEmpty ? before.last : withM.first;
    final end = withM.last;
    measures.add(ReportMeasure(measure: m, start: start.values[m]!, end: end.values[m]!, startDate: start.date));
  }

  final cks = checkins.where((c) => !dateOnly(c.date).isBefore(from)).toList();

  return ReportData(
    name: name,
    from: from,
    to: today,
    period: period,
    workouts: [
      for (final s in inPeriod)
        ReportWorkout(
          date: s.startedAt,
          title: s.dayTitle,
          sets: s.completedSets,
          planned: s.plannedSets,
          minutes: s.activeDuration(s.finishedAt ?? s.startedAt).inMinutes,
          warmup: s.warmup,
          cooldown: s.cooldown,
        ),
    ],
    plannedDays: planned,
    muscleSets: muscleSets,
    weeks: days / 7,
    strength: strength,
    measures: measures,
    moodAvg: _avg(cks.map((c) => c.mood)),
    energyAvg: _avg(cks.map((c) => c.energy)),
    sleepAvg: _avg(cks.map((c) => c.sleep)),
    checkins: cks.length,
    currentStreak: currentStreak,
    bestStreak: bestStreak,
    notes: notes,
  );
}
