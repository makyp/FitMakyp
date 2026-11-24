import 'package:fitmakyp/core/models/body.dart';
import 'package:fitmakyp/core/models/exercise.dart';
import 'package:fitmakyp/core/models/session.dart';
import 'package:fitmakyp/features/evolution/domain/progress_analysis.dart';
import 'package:fitmakyp/features/history/domain/week_insights.dart';
import 'package:flutter_test/flutter_test.dart';

WorkoutSession _s(String id, DateTime at, int sets, {int minutes = 40}) => WorkoutSession(
      id: id,
      planId: 'p',
      dayId: 'd',
      dayTitle: 'Día',
      status: SessionStatus.completed,
      startedAt: at,
      finishedAt: at.add(Duration(minutes: minutes)),
      exercises: [
        SessionExercise(
          workoutExerciseId: 'w',
          exerciseId: 'e',
          name: 'e',
          plannedSets: sets,
          target: const SetTarget.reps(10),
          restSeconds: 60,
          sets: [for (var i = 0; i < sets; i++) ExerciseSetLog(setNumber: i + 1, result: SetResult.completed, finishedAt: at)],
        ),
      ],
    );

void main() {
  group('categorías de mejora', () {
    MeasureComparison c(double from, double to, Trend t) =>
        MeasureComparison(measure: Measure.cintura, from: from, to: to, trend: t);

    test('reducir: cuanto más baja, mejor categoría', () {
      expect(c(80, 79.8, Trend.reduce).tier, ImprovementTier.gris); // 0,25 %
      expect(c(80, 79, Trend.reduce).tier, ImprovementTier.amarillo); // 1,25 %
      expect(c(80, 77, Trend.reduce).tier, ImprovementTier.azul); // 3,75 %
      expect(c(80, 75, Trend.reduce).tier, ImprovementTier.morado); // 6,25 %
      expect(c(80, 82, Trend.reduce).tier, ImprovementTier.gris, reason: 'en sentido contrario: gris, sin castigo');
    });

    test('aumentar (glúteos) y solo seguir', () {
      expect(c(95, 100, Trend.increase).tier, ImprovementTier.morado);
      expect(c(95, 100, Trend.neutral).tier, ImprovementTier.seguimiento);
    });

    test('ranking: primero las mejores mejoras con objetivo', () {
      final r = compareRecords(
        {Measure.cintura: 80, Measure.gluteos: 95, Measure.pecho: 90, Measure.abdomen: 85},
        {Measure.cintura: 78, Measure.gluteos: 100, Measure.pecho: 89, Measure.abdomen: 85},
        defaultTrends,
      );
      expect(r.map((x) => x.measure), [Measure.gluteos, Measure.cintura, Measure.abdomen, Measure.pecho]);
    });
  });

  test('registro del mes anterior y valores completados para la silueta', () {
    final recs = [
      ProgressRecord(id: 'a', date: DateTime(2026, 9, 1), values: {Measure.cintura: 80, Measure.cadera: 100}),
      ProgressRecord(id: 'b', date: DateTime(2026, 10, 9), values: {Measure.cintura: 78}),
      ProgressRecord(id: 'c', date: DateTime(2026, 10, 25), values: {Measure.cintura: 77}),
      ProgressRecord(id: 'd', date: DateTime(2026, 11, 10), values: {Measure.cintura: 76}),
    ];
    expect(monthAgoRecord(recs)!.id, 'b');
    final filled = filledValues(recs, recs.last);
    expect(filled[Measure.cintura], 76);
    expect(filled[Measure.cadera], 100, reason: 'usa el último dato conocido');
  });

  test('IMC y categorías', () {
    expect(bmi(65, 165), closeTo(23.9, 0.05));
    expect(bmiCategory(17).label, 'Bajo peso');
    expect(bmiCategory(23.9), BmiCategory.normal);
    expect(bmiCategory(27), BmiCategory.sobrepeso);
    expect(bmiCategory(31), BmiCategory.obesidad);
    final (lo, hi) = healthyWeightRange(165);
    expect(lo, closeTo(50.4, 0.1));
    expect(hi, closeTo(67.8, 0.1));
  });

  test('resumen semanal y mejor semana', () {
    final mon1 = DateTime(2026, 11, 2);
    final mon2 = DateTime(2026, 11, 9);
    final data = InsightsData(
      sessions: [
        _s('1', mon1.add(const Duration(hours: 18)), 10),
        _s('2', mon2.add(const Duration(hours: 18)), 12),
        _s('3', mon2.add(const Duration(days: 1, hours: 18)), 15, minutes: 55),
      ],
      checkins: [
        DailyCheckin(date: mon2, mood: 5),
        DailyCheckin(date: mon2.add(const Duration(days: 1)), mood: 4),
      ],
      records: const [],
      glasses: (d) => d == mon2 ? 8 : 2,
      waterGoal: 8,
      habitsDone: (d) => 1,
      habitsCount: 4,
    );
    final w = weekSummary(data, mon2.add(const Duration(days: 3)));
    expect(w.monday, mon2);
    expect(w.workouts, 2);
    expect(w.sets, 27);
    expect(w.time.inMinutes, 95);
    expect(w.waterGoalDays, 1);
    expect(w.mood, 4.5);

    final b = personalBests(data, DateTime(2026, 11, 12));
    expect(b.bestWeek!.monday, mon2);
    expect(b.longestWorkout!.id, '3');
    expect(b.mostSetsWorkout!.id, '3');
  });
}
