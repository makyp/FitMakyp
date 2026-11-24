import 'package:fitmakyp/app_scope.dart';
import 'package:fitmakyp/core/models/body.dart';
import 'package:fitmakyp/core/notifications/reminders.dart';
import 'package:fitmakyp/core/storage/local_store.dart';
import 'package:fitmakyp/features/challenges/challenges_screen.dart';
import 'package:fitmakyp/features/challenges/domain/challenges.dart';
import 'package:fitmakyp/features/evolution/domain/mood_trends.dart';
import 'package:fitmakyp/features/evolution/state/body_repository.dart';
import 'package:fitmakyp/features/evolution/ui/mood_screen.dart';
import 'package:fitmakyp/features/goals/domain/rewards.dart';
import 'package:fitmakyp/features/goals/state/goals_repository.dart';
import 'package:fitmakyp/features/goals/state/rewards_service.dart';
import 'package:fitmakyp/features/habits/state/habits_repository.dart';
import 'package:fitmakyp/features/history/state/history_repository.dart';
import 'package:fitmakyp/features/library/state/library_repository.dart';
import 'package:fitmakyp/features/pet/domain/pet_items.dart';
import 'package:fitmakyp/features/pet/state/pet_repository.dart';
import 'package:fitmakyp/features/plans/state/plan_repository.dart';
import 'package:fitmakyp/features/settings/state/settings_repository.dart';
import 'package:fitmakyp/features/summary/month_summary_screen.dart';
import 'package:fitmakyp/features/workout/state/workout_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes.dart';

DateTime d(int m, int day) => DateTime(2026, m, day);

void main() {
  group('retos semanales', () {
    final monday = d(11, 9);
    final input = ChallengeInput(
      trained: {d(11, 9), d(11, 11), d(11, 13)},
      water: {d(11, 9), d(11, 10)},
      morning: {d(11, 10), d(11, 11), d(11, 12)},
      checkins: {d(11, 9)},
    );

    test('siempre hay 3 retos y entrenar es uno', () {
      final w = challengesOfWeek(monday, input);
      expect(w, hasLength(3));
      expect(w.first, ChallengeKind.entrenar);
      expect(w.toSet(), hasLength(3));
    });

    test('progreso de la semana', () {
      final st = weekStatus(monday, input);
      expect(st.first.progress, 3);
      expect(st.first.done, isTrue);
    });

    test('los premios se desbloquean por semanas perfectas', () {
      expect(unlockedPrizes(0), isEmpty);
      expect(unlockedPrizes(2), ['tiara_estrellas', 'banda_campeona']);
      for (final id in challengePrizes) {
        expect(petItemById(id)?.prize, isTrue, reason: id);
      }
    });
  });

  test('puntos nuevos: rutina matutina y retos', () {
    final base = RewardsInput(sessions: const [], records: const [], checkins: const [], goals: const [], currentStreak: 0, bestStreak: 0, now: d(11, 13));
    final more = RewardsInput(
      sessions: const [],
      records: const [],
      checkins: const [],
      goals: const [],
      currentStreak: 0,
      bestStreak: 0,
      now: d(11, 13),
      morningDays: {d(11, 3)},
      challengesCompleted: 2,
    );
    expect(totalEarned(more) - totalEarned(base),
        PointRules.morning + 2 * PointRules.challenge);
  });

  test('ánimo: serie semanal y entreno vs descanso', () {
    final c = [
      DailyCheckin(date: d(11, 2), mood: 4, energy: 3),
      DailyCheckin(date: d(11, 3), mood: 2, energy: 2),
      DailyCheckin(date: d(11, 4), mood: 5, energy: 4),
      DailyCheckin(date: d(11, 5), mood: 3, energy: 3),
      DailyCheckin(date: d(11, 10), mood: 4, energy: 4),
    ];
    final weekly = moodSeries(c, from: d(11, 1), to: d(11, 13), weekly: true);
    expect(weekly, hasLength(2));
    expect(weekly.first.mood, 3.5);
    final cmp = moodWithAndWithoutTraining(c, {d(11, 2), d(11, 4)});
    expect(cmp, (4.5, 3.0));
    expect(bestWeekday(c, min: 1), DateTime.wednesday);
  });

  test('aviso 2 días antes de la regla, a las 9', () {
    expect(periodReminderAt(nextStart: d(11, 20), now: d(11, 13)), DateTime(2026, 11, 18, 9));
    expect(periodReminderAt(nextStart: d(11, 14), now: d(11, 13)), isNull);
    expect(periodReminderAt(nextStart: null, now: d(11, 13)), isNull);
  });

  test('resumen del mes: los primeros días muestra el mes anterior', () {
    expect(defaultSummaryMonth(d(12, 2)), DateTime(2026, 11));
    expect(defaultSummaryMonth(d(11, 13)), DateTime(2026, 11));
  });

  for (final (name, screen) in [
    ('Mi ánimo', const MoodScreen()),
    ('Retos', const ChallengesScreen()),
    ('Mi mes', const MonthSummaryScreen()),
  ]) {
    testWidgets('la pantalla $name se dibuja sin errores', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      final store = await LocalStore.open();
      final settings = SettingsRepository(store);
      final library = LibraryRepository(store);
      final plans = PlanRepository(store);
      final history = HistoryRepository(store);
      final workout = WorkoutController(store: store, history: history, library: library, settings: settings);
      final body = BodyRepository(store, MemoryPhotoStore());
      final now = DateTime.now();
      for (var i = 0; i < 6; i++) {
        await body.saveCheckin(DailyCheckin(date: DateTime(now.year, now.month, now.day - i), mood: 2 + i % 4, energy: 3));
      }
      final goals = GoalsRepository(store);
      final pet = PetRepository(store);
      final habits = HabitsRepository(store);
      final rewards = RewardsService(history: history, body: body, goals: goals, pet: pet, plans: plans, habits: habits, store: store);
      await tester.pumpWidget(AppScope(
        store: store,
        body: body,
        goals: goals,
        pet: pet,
        rewards: rewards,
        habits: habits,
        settings: settings,
        library: library,
        plans: plans,
        history: history,
        workout: workout,
        child: MaterialApp(home: screen),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      await tester.drag(find.byType(ListView).first, const Offset(0, -1200));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
    });
  }
}
