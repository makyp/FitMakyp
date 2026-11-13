/// Resumen semanal, mejor semana y récords personales. Lógica pura.
library;

import '../../../core/models/body.dart';
import '../../../core/models/habits.dart';
import '../../../core/models/session.dart';
import '../../../core/utils/format.dart';

/// Acceso a los datos de cada día (lo rellenan los repositorios).
class InsightsData {
  const InsightsData({
    required this.sessions,
    required this.checkins,
    required this.records,
    required this.glasses,
    required this.waterGoal,
    required this.habitsDone,
    required this.habitsCount,
    required this.meals,
  });

  final List<WorkoutSession> sessions;
  final List<DailyCheckin> checkins;
  final List<ProgressRecord> records;
  final int Function(DateTime day) glasses;
  final int waterGoal;
  final int Function(DateTime day) habitsDone;
  final int habitsCount;
  final List<MealEntry> Function(DateTime day) meals;
}

DateTime mondayOf(DateTime d) {
  final x = dateOnly(d);
  return x.subtract(Duration(days: x.weekday - 1));
}

class DayInsight {
  DayInsight({
    required this.day,
    required this.sessions,
    required this.checkin,
    required this.glasses,
    required this.habitsDone,
    required this.meals,
    required this.record,
  });

  final DateTime day;
  final List<WorkoutSession> sessions;
  final DailyCheckin? checkin;
  final int glasses;
  final int habitsDone;
  final List<MealEntry> meals;
  final ProgressRecord? record;

  bool get trained => sessions.any((s) => s.completedSets > 0);
  int get protein => meals.fold(0, (a, m) => a + (m.protein ?? 0));
  int get kcal => meals.fold(0, (a, m) => a + (m.kcal ?? 0));
  bool get isEmpty =>
      sessions.isEmpty && checkin == null && glasses == 0 && habitsDone == 0 && meals.isEmpty && record == null;
}

class WeekSummary {
  WeekSummary(this.monday, this.days, this.waterGoal, this.habitsCount);

  final DateTime monday;
  final List<DayInsight> days;
  final int waterGoal;
  final int habitsCount;

  List<WorkoutSession> get _done => [for (final d in days) ...d.sessions.where((s) => s.completedSets > 0)];
  int get workouts => days.where((d) => d.trained).length;
  int get sets => _done.fold(0, (a, s) => a + s.completedSets);
  Duration get time => _done.fold(Duration.zero, (a, s) => a + s.activeDuration(s.finishedAt ?? s.startedAt));
  int get glasses => days.fold(0, (a, d) => a + d.glasses);
  int get waterGoalDays => days.where((d) => d.glasses >= waterGoal).length;
  int get habitsDone => days.fold(0, (a, d) => a + d.habitsDone);
  int get habitsPossible => habitsCount * 7;
  int get checkins => days.where((d) => d.checkin != null).length;
  bool get hasActivity => days.any((d) => !d.isEmpty);

  double? _avg(int Function(DailyCheckin c) f) {
    final cs = [for (final d in days) ?d.checkin];
    return cs.isEmpty ? null : cs.map(f).reduce((a, b) => a + b) / cs.length;
  }

  double? get mood => _avg((c) => c.mood);
  double? get energy => _avg((c) => c.energy);
  double? get sleep => _avg((c) => c.sleep);
  double? get activity => _avg((c) => c.activity);

  /// Puntuación para elegir la mejor semana: entrenos pesan más; agua, hábitos y registro diario suman.
  double get score => workouts * 10 + sets * 0.2 + waterGoalDays * 2 + habitsDone * 0.5 + checkins * 1;
}

WeekSummary weekSummary(InsightsData data, DateTime anyDayInWeek) {
  final monday = mondayOf(anyDayInWeek);
  final days = [
    for (var i = 0; i < 7; i++)
      () {
        final day = monday.add(Duration(days: i));
        return DayInsight(
          day: day,
          sessions: data.sessions.where((s) => dateOnly(s.startedAt) == day).toList()
            ..sort((a, b) => a.startedAt.compareTo(b.startedAt)),
          checkin: data.checkins.where((c) => dateOnly(c.date) == day).firstOrNull,
          glasses: data.glasses(day),
          habitsDone: data.habitsDone(day),
          meals: data.meals(day),
          record: data.records.where((r) => dateOnly(r.date) == day).firstOrNull,
        );
      }(),
  ];
  return WeekSummary(monday, days, data.waterGoal, data.habitsCount);
}

/// Semanas con alguna actividad, desde la primera hasta [now].
List<WeekSummary> allWeeks(InsightsData data, DateTime now) {
  final dates = [
    ...data.sessions.map((s) => s.startedAt),
    ...data.checkins.map((c) => c.date),
    ...data.records.map((r) => r.date),
  ];
  if (dates.isEmpty) return [weekSummary(data, now)];
  var m = mondayOf(dates.reduce((a, b) => a.isBefore(b) ? a : b));
  final last = mondayOf(now);
  final out = <WeekSummary>[];
  while (!m.isAfter(last)) {
    out.add(weekSummary(data, m));
    m = DateTime(m.year, m.month, m.day + 7);
  }
  return out;
}

class PersonalBests {
  PersonalBests({
    this.bestWeek,
    this.mostWorkoutsWeek,
    this.bestMoodWeek,
    this.longestWorkout,
    this.mostSetsWorkout,
    this.bestWaterWeek,
    this.activeWeeks = 0,
  });

  final WeekSummary? bestWeek;
  final WeekSummary? mostWorkoutsWeek;
  final WeekSummary? bestMoodWeek;
  final WeekSummary? bestWaterWeek;
  final WorkoutSession? longestWorkout;
  final WorkoutSession? mostSetsWorkout;

  /// Semanas con alguna actividad (para no hablar de "mejor semana" si solo hay una).
  final int activeWeeks;
}

PersonalBests personalBests(InsightsData data, DateTime now) {
  final weeks = allWeeks(data, now).where((w) => w.hasActivity).toList();
  T? maxBy<T>(Iterable<T> xs, num Function(T) f) {
    T? best;
    for (final x in xs) {
      if (best == null || f(x) > f(best)) best = x;
    }
    return best;
  }

  final done = data.sessions.where((s) => s.completedSets > 0);
  return PersonalBests(
    bestWeek: maxBy(weeks, (w) => w.score),
    mostWorkoutsWeek: maxBy(weeks.where((w) => w.workouts > 0), (w) => w.workouts * 1000 + w.sets),
    bestMoodWeek: maxBy(weeks.where((w) => w.checkins >= 2), (w) => w.mood ?? 0),
    bestWaterWeek: maxBy(weeks.where((w) => w.waterGoalDays > 0), (w) => w.waterGoalDays * 1000 + w.glasses),
    activeWeeks: weeks.length,
    longestWorkout: maxBy(done, (s) => s.activeDuration(s.finishedAt ?? s.startedAt).inSeconds),
    mostSetsWorkout: maxBy(done, (s) => s.completedSets),
  );
}
