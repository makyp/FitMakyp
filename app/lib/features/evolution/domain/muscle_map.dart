/// Mapa muscular: cuánto se ha entrenado cada zona del cuerpo y cómo cambian las medidas por zona.
/// Lógica pura (sin Flutter salvo colores) para poder probarla.
library;

import 'dart:ui' show Color;

import '../../../core/models/body.dart';
import '../../../core/models/exercise.dart';
import '../../../core/models/session.dart';
import '../../../core/utils/format.dart';
import 'progress_analysis.dart';

enum BodyView { frente, espalda }

/// Zonas que se dibujan en el mapa. [front]/[back] indican en qué vista aparecen.
enum BodyZone {
  trapecio('Trapecio', front: true, back: true),
  deltoides('Hombros', front: true, back: true),
  pecho('Pecho', front: true),
  biceps('Bíceps', front: true),
  triceps('Tríceps', back: true),
  antebrazos('Antebrazos', front: true, back: true),
  abdomen('Abdomen', front: true),
  oblicuos('Oblicuos', front: true),
  dorsales('Espalda (dorsales)', back: true),
  lumbar('Zona lumbar', back: true),
  gluteos('Glúteos', back: true),
  abductores('Abductores (cadera)', front: true, back: true),
  aductores('Aductores', front: true),
  cuadriceps('Cuádriceps', front: true),
  isquiotibiales('Isquiotibiales', back: true),
  gemelos('Gemelos y pantorrillas', front: true, back: true);

  const BodyZone(this.label, {this.front = false, this.back = false});
  final String label;
  final bool front;
  final bool back;

  bool inView(BodyView v) => v == BodyView.frente ? front : back;

  /// Grupos musculares (de la biblioteca de ejercicios) que trabajan esta zona.
  List<MuscleGroup> get muscles => switch (this) {
        trapecio => const [MuscleGroup.espalda, MuscleGroup.hombros],
        deltoides => const [MuscleGroup.hombros],
        pecho => const [MuscleGroup.pecho],
        biceps => const [MuscleGroup.biceps],
        triceps => const [MuscleGroup.triceps],
        antebrazos => const [MuscleGroup.biceps],
        abdomen => const [MuscleGroup.abdomen, MuscleGroup.core],
        oblicuos => const [MuscleGroup.core],
        dorsales => const [MuscleGroup.espalda],
        lumbar => const [MuscleGroup.espalda, MuscleGroup.core],
        gluteos => const [MuscleGroup.gluteos],
        abductores => const [MuscleGroup.abductores],
        aductores => const [MuscleGroup.aductores],
        cuadriceps => const [MuscleGroup.cuadriceps],
        isquiotibiales => const [MuscleGroup.isquiotibiales],
        gemelos => const [MuscleGroup.gemelos],
      };

  /// Medida que refleja esta zona. [side] es el lado de la persona: -1 derecho, 1 izquierdo, 0 centro.
  Measure? measure(int side) => switch (this) {
        pecho => Measure.pecho,
        abdomen => Measure.abdomen,
        oblicuos || lumbar => Measure.cintura,
        gluteos => Measure.gluteos,
        abductores => Measure.cadera,
        cuadriceps || isquiotibiales || aductores => side < 0 ? Measure.musloDer : Measure.musloIzq,
        biceps || triceps => side < 0 ? Measure.brazoDer : Measure.brazoIzq,
        _ => null,
      };
}

/// Periodo para contar el entrenamiento.
enum TrainingPeriod {
  semana('7 días', 7),
  mes('30 días', 30),
  todo('Todo', null);

  const TrainingPeriod(this.label, this.days);
  final String label;
  final int? days;
}

/// Nivel de entrenamiento de una zona, con los mismos colores que las mejoras.
enum TrainingLevel {
  nada('Sin entrenar', 'Aún no hay series en este periodo', Color(0xFFC9C3D3)),
  poco('Poco', 'Menos de 4 series por semana', Color(0xFFF2C14E)),
  bien('Bien', 'De 4 a 9 series por semana', Color(0xFF4F8FD9)),
  mucho('Mucho', '10 series o más por semana', Color(0xFF7041B8));

  const TrainingLevel(this.label, this.description, this.color);
  final String label;
  final String description;
  final Color color;

  static TrainingLevel of(double setsPerWeek) {
    if (setsPerWeek <= 0) return nada;
    if (setsPerWeek < 4) return poco;
    if (setsPerWeek < 10) return bien;
    return mucho;
  }
}

/// Entrenamiento acumulado de un grupo muscular.
class MuscleStats {
  MuscleStats(this.muscle);
  final MuscleGroup muscle;

  /// Series: 1 por serie si es el músculo principal, 0,5 si es secundario.
  double sets = 0;
  final Set<String> sessionIds = {};
  DateTime? last;
  final Map<String, double> byExercise = {};

  int get sessions => sessionIds.length;
}

class TrainingMap {
  TrainingMap(this.stats, this.weeks);

  final Map<MuscleGroup, MuscleStats> stats;

  /// Semanas que abarca el periodo (para normalizar a series por semana).
  final double weeks;

  double setsOf(MuscleGroup m) => stats[m]?.sets ?? 0;

  /// Series de la zona: suma de los grupos que la trabajan.
  double zoneSets(BodyZone z) => z.muscles.fold(0, (a, m) => a + setsOf(m));

  TrainingLevel zoneLevel(BodyZone z) => TrainingLevel.of(zoneSets(z) / weeks);

  TrainingLevel muscleLevel(MuscleGroup m) => TrainingLevel.of(setsOf(m) / weeks);

  /// Músculos ordenados de más a menos series.
  List<MuscleStats> get ranking => stats.values.toList()..sort((a, b) => b.sets.compareTo(a.sets));
}

/// Cuenta las series completadas por grupo muscular desde el inicio del periodo hasta [now].
TrainingMap trainingMap(
  List<WorkoutSession> sessions,
  Exercise? Function(String id) exerciseById,
  TrainingPeriod period,
  DateTime now, {
  int? days,
}) {
  final periodDays = days ?? period.days;
  final from = periodDays == null ? null : dateOnly(now).subtract(Duration(days: periodDays - 1));
  final inPeriod = sessions.where((s) => from == null || !s.startedAt.isBefore(from)).toList();
  final stats = <MuscleGroup, MuscleStats>{};

  void add(MuscleGroup m, double sets, WorkoutSession s, String exName) {
    final st = stats.putIfAbsent(m, () => MuscleStats(m));
    st.sets += sets;
    st.sessionIds.add(s.id);
    st.byExercise[exName] = (st.byExercise[exName] ?? 0) + sets;
    if (st.last == null || s.startedAt.isAfter(st.last!)) st.last = s.startedAt;
  }

  for (final s in inPeriod) {
    for (final e in s.exercises) {
      final done = e.sets.where((x) => x.result == SetResult.completed).length;
      if (done == 0) continue;
      final ex = exerciseById(e.exerciseId);
      if (ex == null) continue;
      add(ex.primaryMuscle, done.toDouble(), s, e.name);
      for (final m in ex.secondaryMuscles) {
        if (m != ex.primaryMuscle) add(m, done * 0.5, s, e.name);
      }
    }
  }

  double weeks;
  if (periodDays != null) {
    weeks = periodDays / 7;
  } else if (inPeriod.isEmpty) {
    weeks = 1;
  } else {
    final first = inPeriod.map((s) => s.startedAt).reduce((a, b) => a.isBefore(b) ? a : b);
    weeks = (dateOnly(now).difference(dateOnly(first)).inDays + 1) / 7;
  }
  return TrainingMap(stats, weeks < 1 ? 1 : weeks);
}

/// Color de una zona según el cambio de su medida entre dos registros.
ImprovementTier? zoneTier(
  BodyZone z,
  int side,
  Map<Measure, double>? before,
  Map<Measure, double> now,
  Map<Measure, Trend> trends,
) {
  final m = z.measure(side);
  if (m == null || before == null) return null;
  final a = before[m], b = now[m];
  if (a == null || b == null) return null;
  return MeasureComparison(measure: m, from: a, to: b, trend: trends[m] ?? Trend.neutral).tier;
}

/// Sugerencia para equilibrar el entrenamiento.
class MuscleSuggestion {
  const MuscleSuggestion({required this.muscle, required this.reason, required this.exercises});
  final MuscleGroup muscle;
  final String reason;
  final List<Exercise> exercises;
}

/// Músculos principales que conviene trabajar cada semana.
const balanceMuscles = [
  MuscleGroup.gluteos,
  MuscleGroup.cuadriceps,
  MuscleGroup.isquiotibiales,
  MuscleGroup.espalda,
  MuscleGroup.pecho,
  MuscleGroup.hombros,
  MuscleGroup.core,
  MuscleGroup.biceps,
  MuscleGroup.triceps,
];

/// Qué músculos van atrasados (en [m], normalmente los últimos 14 días) y qué ejercicios añadir.
/// [inPlan] son los ejercicios que ya están en la rutina (se proponen otros primero).
List<MuscleSuggestion> balanceSuggestions(TrainingMap m, List<Exercise> library, Set<String> inPlan, {int max = 3}) {
  double perWeek(MuscleGroup g) =>
      (g == MuscleGroup.core ? m.setsOf(MuscleGroup.core) + m.setsOf(MuscleGroup.abdomen) : m.setsOf(g)) / m.weeks;
  final total = m.stats.values.fold<double>(0, (a, s) => a + s.sets);
  if (total == 0) return const [];

  final reasons = <MuscleGroup, String>{};
  // Desequilibrios entre músculos que trabajan en pareja.
  for (final (a, b) in const [
    (MuscleGroup.cuadriceps, MuscleGroup.isquiotibiales),
    (MuscleGroup.pecho, MuscleGroup.espalda),
    (MuscleGroup.biceps, MuscleGroup.triceps),
  ]) {
    for (final (x, y) in [(a, b), (b, a)]) {
      if (perWeek(x) >= 4 && perWeek(x) >= 2 * perWeek(y) + 1) {
        reasons[y] = 'Trabajas ${x.label.toLowerCase()} mucho más que ${y.label.toLowerCase()}: equilibrarlos cuida tus articulaciones.';
      }
    }
  }
  for (final g in balanceMuscles) {
    final w = perWeek(g);
    if (reasons.containsKey(g)) continue;
    if (w == 0) {
      reasons[g] = 'No lo has trabajado en las últimas 2 semanas.';
    } else if (w < 2 && g != MuscleGroup.biceps && g != MuscleGroup.triceps) {
      reasons[g] = 'Solo ${w.toStringAsFixed(1).replaceAll('.', ',')} series por semana: con 4 o más notarás más progreso.';
    }
  }

  final ordered = [for (final g in balanceMuscles) if (reasons.containsKey(g)) g];
  ordered.sort((a, b) => perWeek(a).compareTo(perWeek(b)));
  return [
    for (final g in ordered.take(max))
      MuscleSuggestion(
        muscle: g,
        reason: reasons[g]!,
        exercises: (library
                .where((e) =>
                    e.primaryMuscle == g || (g == MuscleGroup.core && e.primaryMuscle == MuscleGroup.abdomen))
                .toList()
              ..sort((a, b) {
                final p = (inPlan.contains(a.id) ? 1 : 0) - (inPlan.contains(b.id) ? 1 : 0);
                return p != 0 ? p : a.difficulty.index - b.difficulty.index;
              }))
            .take(3)
            .toList(),
      ),
  ];
}
