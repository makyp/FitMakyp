import 'package:fitmakyp/app_scope.dart';
import 'package:fitmakyp/core/data/seed_exercises.dart';
import 'package:fitmakyp/core/data/starter_plans.dart';
import 'package:fitmakyp/core/storage/local_store.dart';
import 'package:fitmakyp/features/evolution/state/body_repository.dart';
import 'package:fitmakyp/features/goals/state/goals_repository.dart';
import 'package:fitmakyp/features/goals/state/rewards_service.dart';
import 'package:fitmakyp/features/habits/state/habits_repository.dart';
import 'package:fitmakyp/features/history/state/history_repository.dart';
import 'package:fitmakyp/features/library/state/library_repository.dart';
import 'package:fitmakyp/features/onboarding/onboarding_screen.dart';
import 'package:fitmakyp/features/pet/state/pet_repository.dart';
import 'package:fitmakyp/features/plans/state/plan_repository.dart';
import 'package:fitmakyp/features/settings/state/settings_repository.dart';
import 'package:fitmakyp/features/workout/state/workout_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes.dart';

void main() {
  test('todas las rutinas iniciales usan ejercicios que existen', () {
    final ids = {for (final e in seedExercises) e.id};
    for (final days in [2, 3, 4, 5]) {
      for (final place in StarterPlace.values) {
        for (final level in StarterLevel.values) {
          for (final focus in StarterFocus.values) {
            final p = buildStarterPlan(daysPerWeek: days, place: place, level: level, focus: focus);
            final training = p.days.where((d) => d.isTraining).toList();
            expect(training, hasLength(days));
            expect(p.days, hasLength(7));
            final weIds = [for (final d in training) ...d.exercises.map((e) => e.id)];
            expect(weIds.toSet().length, weIds.length, reason: 'ids únicos');
            for (final d in training) {
              expect(d.exercises.length, greaterThanOrEqualTo(4));
              for (final e in d.exercises) {
                expect(ids, contains(e.exerciseId), reason: '${e.exerciseId} en $days días ${place.name}');
              }
            }
          }
        }
      }
    }
  });

  test('quien ya tenía datos no ve la bienvenida y conserva su nombre', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await LocalStore.open();
    await store.writeJson('history', []);
    await skipOnboardingForExistingUser(store);
    expect(store.readJson(onboardedKey), isTrue);
    expect(SettingsRepository(store).settings.userName, 'Makyp');

    SharedPreferences.setMockInitialValues({});
    final fresh = await LocalStore.open();
    await skipOnboardingForExistingUser(fresh);
    expect(fresh.readJson(onboardedKey), isNull);
  });

  testWidgets('la bienvenida configura nombre, rutina y hábitos', (tester) async {
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
    var done = false;
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
      child: MaterialApp(home: OnboardingScreen(onDone: () => done = true)),
    ));
    await tester.pump();
    await tester.tap(find.text('EMPEZAR'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    // Sin nombre no se puede seguir.
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'SIGUIENTE')).onPressed, isNull);
    await tester.enterText(find.byType(TextField).first, 'Ana');
    await tester.tap(find.text('Mujer'));
    await tester.pump();
    await tester.tap(find.text('SIGUIENTE'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('4 días'));
    await tester.tap(find.text('En casa, sin equipo'));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('SIGUIENTE'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('SIGUIENTE'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('¡EMPEZAR!'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    expect(done, isTrue);
    expect(settings.settings.userName, 'Ana');
    expect(settings.settings.showCycle, isTrue);
    expect(plans.active.days.where((d) => d.isTraining), hasLength(4));
    expect(plans.plans.any((p) => p.id == 'plan_inicial'), isFalse);
    expect(store.readJson(onboardedKey), isTrue);
  });
}
