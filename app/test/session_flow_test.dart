import 'package:fitmakyp/app_scope.dart';
import 'package:fitmakyp/core/models/exercise.dart';
import 'package:fitmakyp/core/models/plan.dart';
import 'package:fitmakyp/core/storage/local_store.dart';
import 'package:fitmakyp/features/evolution/state/body_repository.dart';
import 'package:fitmakyp/features/goals/state/goals_repository.dart';
import 'package:fitmakyp/features/goals/state/rewards_service.dart';
import 'package:fitmakyp/features/habits/state/habits_repository.dart';
import 'package:fitmakyp/features/pet/state/pet_repository.dart';
import 'package:fitmakyp/features/history/state/history_repository.dart';
import 'package:fitmakyp/features/library/state/library_repository.dart';
import 'package:fitmakyp/features/plans/state/plan_repository.dart';
import 'package:fitmakyp/features/settings/state/settings_repository.dart';
import 'package:fitmakyp/features/workout/state/workout_controller.dart';
import 'package:fitmakyp/features/workout/ui/session_screen.dart';
import 'package:fitmakyp/features/workout/ui/summary_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes.dart';

void main() {
  testWidgets('al completar la última serie se abre el resumen (no se queda cargando)', (tester) async {
    // Pantalla de móvil (Pixel 6a).
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

    const day = WorkoutDay(
      id: 'test',
      weekday: 1,
      kind: DayKind.training,
      title: 'Prueba',
      exercises: [WorkoutExercise(id: 'w', exerciseId: 'flexiones', sets: 1, target: SetTarget.reps(10))],
    );
    await workout.start(plans.active, day);

    await tester.pumpWidget(
      AppScope(
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
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SessionScreen())),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    // Las animaciones (mascota, movimiento) son infinitas: nada de pumpAndSettle.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Primero el calentamiento: "Ya calenté" lo marca y arranca el entrenamiento.
    expect(find.text('CALENTAR AHORA'), findsOneWidget);
    await tester.ensureVisible(find.text('Ya calenté'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Ya calenté'));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('SERIE COMPLETADA'));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(SummaryScreen), findsOneWidget);
    expect(find.text('¡Entrenamiento completado!'), findsOneWidget);
    expect(history.sessions, hasLength(1));
    expect(history.sessions.single.warmup, 'alreadyDone');
    expect(find.text('ESTIRAR AHORA'), findsOneWidget, reason: 'al terminar se ofrecen los estiramientos');
    expect(workout.session, isNull);

    workout.dispose();
  });
}
