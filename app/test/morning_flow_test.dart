import 'package:fitmakyp/app_scope.dart';
import 'package:fitmakyp/core/storage/local_store.dart';
import 'package:fitmakyp/features/evolution/state/body_repository.dart';
import 'package:fitmakyp/features/goals/state/goals_repository.dart';
import 'package:fitmakyp/features/goals/state/rewards_service.dart';
import 'package:fitmakyp/features/habits/state/habits_repository.dart';
import 'package:fitmakyp/features/history/state/history_repository.dart';
import 'package:fitmakyp/features/library/state/library_repository.dart';
import 'package:fitmakyp/features/morning/domain/hypopressive.dart';
import 'package:fitmakyp/features/morning/ui/morning_screen.dart';
import 'package:fitmakyp/features/pet/state/pet_repository.dart';
import 'package:fitmakyp/features/plans/state/plan_repository.dart';
import 'package:fitmakyp/features/settings/state/settings_repository.dart';
import 'package:fitmakyp/features/workout/state/workout_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes.dart';

void main() {
  testWidgets('la rutina matutina se recorre entera y queda marcada como hecha', (tester) async {
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
    final rewards = RewardsService(history: history, body: body, goals: goals, pet: pet, plans: plans, habits: habits);

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
      child: const MaterialApp(home: MorningScreen()),
    ));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(find.text('EMPEZAR'), 300, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('EMPEZAR'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Colócate'), findsOneWidget);
    expect(find.text(hypoPostures.first.name), findsOneWidget);

    // Avanza el reloj hasta la apnea de la primera postura.
    for (var i = 0; i < 40 && find.text('Apnea: abre costillas').evaluate().isEmpty; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(find.text('Apnea: abre costillas'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Salta postura a postura hasta el final.
    for (var i = 0; i < hypoPostures.length; i++) {
      await tester.tap(find.byTooltip('Siguiente postura'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }
    expect(find.text('¡Rutina completa!'), findsOneWidget);
    await tester.tap(find.text('LISTO'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(MorningLog.doneOn(store, DateTime.now()), isTrue);
    expect(find.text('REPETIR'), findsOneWidget);
  });
}
