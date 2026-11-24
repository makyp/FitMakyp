import 'package:fitmakyp/app_scope.dart';
import 'package:fitmakyp/core/data/seed_exercises.dart';
import 'package:fitmakyp/core/models/plan.dart';
import 'package:fitmakyp/core/storage/local_store.dart';
import 'package:fitmakyp/features/boxing/boxing.dart';
import 'package:fitmakyp/features/boxing/boxing_screen.dart';
import 'package:fitmakyp/features/evolution/state/body_repository.dart';
import 'package:fitmakyp/features/goals/state/goals_repository.dart';
import 'package:fitmakyp/features/goals/state/rewards_service.dart';
import 'package:fitmakyp/features/habits/state/habits_repository.dart';
import 'package:fitmakyp/features/history/state/history_repository.dart';
import 'package:fitmakyp/features/library/state/library_repository.dart';
import 'package:fitmakyp/features/pet/state/pet_repository.dart';
import 'package:fitmakyp/features/plans/state/plan_repository.dart';
import 'package:fitmakyp/features/settings/state/settings_repository.dart';
import 'package:fitmakyp/features/workout/state/workout_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes.dart';

void main() {
  test('las sesiones de boxeo usan ejercicios que existen y alternan', () {
    final ids = {for (final e in seedExercises) e.id};
    for (final s in boxingSessions) {
      for (final (id, sets, _, rest) in s.exercises) {
        expect(ids, contains(id));
        expect(sets, greaterThan(0));
        expect(rest, greaterThan(0));
      }
      expect(boxingMinutes(s), inInclusiveRange(20, 50));
    }
    const rest = WorkoutDay(id: 'day_6', weekday: 6, kind: DayKind.rest, title: 'Descanso');
    final a = boxingDay(rest, 0), b = boxingDay(rest, 1);
    expect(a.isTraining, isTrue);
    expect(isBoxingDay(a), isTrue);
    expect(a.title, isNot(b.title));
  });

  testWidgets('la pantalla de boxeo agrega días a la semana', (tester) async {
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
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BoxingScreen())),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('abrir'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
    final button = find.text('AGREGAR A MI SEMANA');
    await tester.scrollUntilVisible(button, 400, scrollable: find.byType(Scrollable).first);
    await tester.tap(button);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    // La rutina inicial tiene sábado y domingo de descanso: se propone el sábado.
    expect(plans.active.days.where(isBoxingDay), isNotEmpty);
    expect(plans.active.dayForWeekday(6)!.title, startsWith('Boxeo'));
  });
}
