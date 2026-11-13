/// Ánimo y energía a lo largo del tiempo (desde el registro diario). Lógica pura.
library;

import '../../../core/models/body.dart';

class MoodPoint {
  const MoodPoint(this.date, this.mood, this.energy, {this.count = 1});
  final DateTime date;
  final double mood;
  final double energy;

  /// Registros que promedia este punto.
  final int count;
}

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);
DateTime mondayOf(DateTime d) => DateTime(d.year, d.month, d.day - (d.weekday - 1));

/// Puntos entre [from] y [to]: uno por día o, si [weekly], la media de cada semana (lunes).
List<MoodPoint> moodSeries(Iterable<DailyCheckin> checkins, {required DateTime from, required DateTime to, bool weekly = false}) {
  final inRange = checkins.where((c) => !_day(c.date).isBefore(_day(from)) && !_day(c.date).isAfter(_day(to))).toList()
    ..sort((a, b) => a.date.compareTo(b.date));
  if (!weekly) return [for (final c in inRange) MoodPoint(_day(c.date), c.mood.toDouble(), c.energy.toDouble())];
  final groups = <DateTime, List<DailyCheckin>>{};
  for (final c in inRange) {
    groups.putIfAbsent(mondayOf(c.date), () => []).add(c);
  }
  return [
    for (final e in groups.entries)
      MoodPoint(
        e.key,
        e.value.fold<int>(0, (a, c) => a + c.mood) / e.value.length,
        e.value.fold<int>(0, (a, c) => a + c.energy) / e.value.length,
        count: e.value.length,
      ),
  ]..sort((a, b) => a.date.compareTo(b.date));
}

/// Ánimo medio los días que entrenaste y los que no (null si hay menos de 2 de alguno).
(double, double)? moodWithAndWithoutTraining(Iterable<DailyCheckin> checkins, Set<DateTime> trained) {
  final days = {for (final d in trained) _day(d)};
  final yes = <int>[], no = <int>[];
  for (final c in checkins) {
    (days.contains(_day(c.date)) ? yes : no).add(c.mood);
  }
  if (yes.length < 2 || no.length < 2) return null;
  double avg(List<int> l) => l.reduce((a, b) => a + b) / l.length;
  return (avg(yes), avg(no));
}

const weekdayNames = ['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'];

/// Día de la semana con mejor ánimo medio (1 = lunes), si hay al menos [min] registros ese día.
int? bestWeekday(Iterable<DailyCheckin> checkins, {int min = 2}) {
  final sums = <int, (int, int)>{};
  for (final c in checkins) {
    final (s, n) = sums[c.date.weekday] ?? (0, 0);
    sums[c.date.weekday] = (s + c.mood, n + 1);
  }
  int? best;
  double bestV = -1;
  for (final e in sums.entries) {
    if (e.value.$2 < min) continue;
    final v = e.value.$1 / e.value.$2;
    if (v > bestV) {
      bestV = v;
      best = e.key;
    }
  }
  return best;
}
