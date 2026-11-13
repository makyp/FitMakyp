/// Metas, puntos y niveles. Lógica pura, sin widgets ni almacenamiento.
///
/// Los puntos ganados se CALCULAN a partir de lo que ya hiciste (historial, registros, metas):
/// así nunca se duplican, sobreviven a una copia de seguridad y no se pueden "perder".
/// Los puntos gastados en la tienda se guardan aparte.
library;

import '../../../core/models/body.dart';
import '../../../core/models/goal.dart';
import '../../../core/models/session.dart';
import '../../../core/utils/format.dart';
import 'achievements.dart';

/// Datos que necesita el cálculo (se rellenan desde los repositorios).
class RewardsInput {
  const RewardsInput({
    required this.sessions,
    required this.records,
    required this.checkins,
    required this.goals,
    required this.currentStreak,
    required this.bestStreak,
    required this.now,
    this.waterGoalDays = const {},
    this.allHabitsDays = const {},
    this.stepGoalDays = const {},
    this.morningDays = const {},
    this.challengesCompleted = 0,
  });

  final List<WorkoutSession> sessions;
  final List<ProgressRecord> records;
  final List<DailyCheckin> checkins;
  final List<Goal> goals;
  final int currentStreak;
  final int bestStreak;
  final DateTime now;

  /// Días (solo fecha) en los que se cumplió la meta de agua / todos los hábitos.
  final Set<DateTime> waterGoalDays;
  final Set<DateTime> allHabitsDays;
  final Set<DateTime> stepGoalDays;
  final Set<DateTime> morningDays;

  /// Retos semanales cumplidos en total.
  final int challengesCompleted;
}

class PointsEntry {
  const PointsEntry(this.reason, this.points);
  final String reason;
  final int points;
}

/// Cómo se ganan los puntos (también se muestra en la app).
abstract final class PointRules {
  static const workout = 20;
  static const fullWorkoutBonus = 10;
  static const progressRecord = 25; // máx. 1 por semana
  static const checkin = 5;
  static const goal = 100;
  static const waterDay = 5;
  static const habitsDay = 5;
  static const stepsDay = 5;
  static const morning = 10;
  static const challenge = 40;
  static const streakMilestones = {3: 30, 7: 70, 14: 150, 30: 300, 60: 600};
}

List<PointsEntry> earnedPoints(RewardsInput i) {
  final out = <PointsEntry>[];
  for (final s in i.sessions) {
    if (s.completedSets == 0) continue;
    out.add(const PointsEntry('Entrenamiento', PointRules.workout));
    if (s.completedSets >= s.plannedSets) out.add(const PointsEntry('Entrenamiento completo', PointRules.fullWorkoutBonus));
  }
  final weeks = <String>{};
  for (final r in i.records) {
    final d = dateOnly(r.date);
    final monday = d.subtract(Duration(days: d.weekday - 1));
    if (weeks.add(monday.toIso8601String())) out.add(const PointsEntry('Registro de progreso', PointRules.progressRecord));
  }
  for (final _ in i.checkins) {
    out.add(const PointsEntry('Registro diario', PointRules.checkin));
  }
  for (final _ in i.waterGoalDays) {
    out.add(const PointsEntry('Meta de agua del día', PointRules.waterDay));
  }
  for (final _ in i.allHabitsDays) {
    out.add(const PointsEntry('Todos los hábitos del día', PointRules.habitsDay));
  }
  for (final _ in i.stepGoalDays) {
    out.add(const PointsEntry('Meta de pasos del día', PointRules.stepsDay));
  }
  for (final _ in i.morningDays) {
    out.add(const PointsEntry('Rutina matutina', PointRules.morning));
  }
  for (var k = 0; k < i.challengesCompleted; k++) {
    out.add(const PointsEntry('Reto semanal', PointRules.challenge));
  }
  for (final g in i.goals.where((g) => g.isCompleted)) {
    out.add(PointsEntry('Meta: ${g.title}', PointRules.goal));
  }
  for (final e in PointRules.streakMilestones.entries) {
    if (i.bestStreak >= e.key) out.add(PointsEntry('Racha de ${e.key} días', e.value));
  }
  out.addAll(achievementPoints(evaluateAchievements(i)));
  return out;
}

int totalEarned(RewardsInput i) => earnedPoints(i).fold(0, (a, e) => a + e.points);

/// Nivel a partir de la experiencia (= puntos ganados en total, gastes o no).
/// Umbrales: 2→100, 3→250, 4→450, 5→700, 6→1000…
int levelThreshold(int level) => 25 * (level - 1) * (level + 2);

int levelFor(int xp) {
  var l = 1;
  while (xp >= levelThreshold(l + 1)) {
    l++;
  }
  return l;
}

/// Avance hacia el siguiente nivel (0..1).
double levelProgress(int xp) {
  final l = levelFor(xp);
  final a = levelThreshold(l);
  final b = levelThreshold(l + 1);
  return (xp - a) / (b - a);
}

class GoalProgress {
  const GoalProgress({required this.fraction, required this.current, required this.target});
  final double fraction;
  final String current;
  final String target;
  bool get reached => fraction >= 1;
}

GoalProgress goalProgress(Goal g, RewardsInput i, {double? latestValue}) {
  String f(double v) => v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);
  switch (g.type) {
    case GoalType.weight:
    case GoalType.measure:
      final start = g.startValue;
      final cur = latestValue;
      if (cur == null || start == null) {
        return GoalProgress(fraction: 0, current: cur == null ? '—' : f(cur), target: f(g.target));
      }
      final total = start - g.target;
      final frac = total == 0 ? 1.0 : ((start - cur) / total).clamp(0.0, 1.0);
      return GoalProgress(fraction: frac, current: f(cur), target: f(g.target));
    case GoalType.streak:
      return GoalProgress(
        fraction: (i.currentStreak / g.target).clamp(0.0, 1.0),
        current: '${i.currentStreak}',
        target: f(g.target),
      );
    case GoalType.workoutsMonth:
      final n = i.sessions
          .where((s) => s.completedSets > 0 && s.startedAt.year == i.now.year && s.startedAt.month == i.now.month)
          .map((s) => dateOnly(s.startedAt))
          .toSet()
          .length;
      return GoalProgress(fraction: (n / g.target).clamp(0.0, 1.0), current: '$n', target: f(g.target));
    case GoalType.waterDays:
      final n = i.waterGoalDays.where((d) => d.year == i.now.year && d.month == i.now.month).length;
      return GoalProgress(fraction: (n / g.target).clamp(0.0, 1.0), current: '$n', target: f(g.target));
    case GoalType.checkins:
      final n = i.checkins.where((c) => c.date.year == i.now.year && c.date.month == i.now.month).length;
      return GoalProgress(fraction: (n / g.target).clamp(0.0, 1.0), current: '$n', target: f(g.target));
  }
}

/// Evita metas extremas de peso: más de ~1 kg por semana o más del 15 % del peso actual.
String? weightGoalWarning({required double current, required double target}) {
  final diff = (current - target).abs();
  if (diff > current * 0.15) {
    return 'Es un cambio grande. Te sugiero una meta intermedia más cercana; cuando la cumplas, pones la siguiente.';
  }
  return null;
}

/// Semanas mínimas razonables para un cambio de peso (~0,5-1 kg/semana).
int suggestedWeeks(double current, double target) => ((current - target).abs() / 0.75).ceil();
