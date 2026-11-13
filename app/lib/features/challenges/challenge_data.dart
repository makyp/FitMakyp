import '../../core/storage/local_store.dart';
import '../../core/utils/format.dart';
import '../evolution/state/body_repository.dart';
import '../habits/state/habits_repository.dart';
import '../history/state/history_repository.dart';
import '../morning/morning_log.dart';
import '../steps/steps_log.dart';
import 'domain/challenges.dart';

/// Reúne de cada parte de la app los días que cuentan para los retos.
ChallengeInput challengeInput({
  required HistoryRepository history,
  required HabitsRepository habits,
  required BodyRepository body,
  LocalStore? store,
}) =>
    ChallengeInput(
      trained: history.trainedDates,
      water: habits.waterGoalDays,
      allHabits: habits.allHabitsDays,
      meals: habits.mealDays,
      checkins: {for (final c in body.checkins) dateOnly(c.date)},
      morning: store == null ? const {} : MorningLog.days(store),
      steps: store == null ? const {} : StepsLog.goalDays(store),
      stepsAvailable: store != null && StepsLog.all(store).isNotEmpty,
      mealsEnabled: habits.settings.nutritionEnabled,
      hasHabits: habits.activeHabits.isNotEmpty,
    );
