/// Cálculo de rachas. Lógica pura.
///
/// Reglas:
/// - Solo cuentan los días con entrenamiento programado.
/// - Los días de descanso NUNCA rompen la racha (tampoco suman, salvo que entrenes ese día).
/// - Un día programado de hoy que aún no has hecho no rompe la racha.
library;

import '../../../core/utils/format.dart';

class StreakStats {
  const StreakStats({required this.current, required this.best});
  final int current;
  final int best;
}

StreakStats computeStreak({
  required Set<DateTime> trainedDates,
  required Set<int> trainingWeekdays,
  required DateTime today,
}) {
  final days = {for (final d in trainedDates) dateOnly(d)};
  final end = dateOnly(today);
  if (days.isEmpty) return const StreakStats(current: 0, best: 0);

  final first = days.reduce((a, b) => a.isBefore(b) ? a : b);
  var run = 0;
  var best = 0;
  for (var d = first; !d.isAfter(end); d = DateTime(d.year, d.month, d.day + 1)) {
    final trained = days.contains(d);
    final scheduled = trainingWeekdays.contains(d.weekday);
    if (trained) {
      run++;
    } else if (scheduled && d != end) {
      run = 0;
    }
    if (run > best) best = run;
  }
  return StreakStats(current: run, best: best);
}
