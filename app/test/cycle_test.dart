import 'package:fitmakyp/app_scope.dart';
import 'package:fitmakyp/core/models/settings.dart';
import 'package:fitmakyp/core/storage/local_store.dart';
import 'package:fitmakyp/features/cycle/cycle_screen.dart';
import 'package:fitmakyp/features/cycle/cycle_store.dart';
import 'package:fitmakyp/features/cycle/domain/cycle.dart';
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
  final periods = [
    Period(DateTime(2026, 8, 20), DateTime(2026, 8, 24)),
    Period(DateTime(2026, 9, 19), DateTime(2026, 9, 23)),
    Period(DateTime(2026, 10, 18), DateTime(2026, 10, 22)),
  ];

  test('medias del ciclo y próxima regla', () {
    final st = CycleStatus.from(periods);
    expect(st.avgCycle, 30); // 30 y 29 -> 29,5 -> 30
    expect(st.avgPeriod, 5);
    expect(st.nextStart, DateTime(2026, 11, 17));
    expect(st.daysUntilNext(DateTime(2026, 11, 13, 10)), 4);
    expect(st.cycleDay(DateTime(2026, 11, 13)), 27);
  });

  test('fases estimadas', () {
    final st = CycleStatus.from(periods);
    expect(st.phaseOn(DateTime(2026, 10, 19)), CyclePhase.menstrual);
    expect(st.phaseOn(DateTime(2026, 10, 25)), CyclePhase.folicular);
    expect(st.phaseOn(DateTime(2026, 11, 3)), CyclePhase.ovulatoria); // día 17 de 30: ovulación ~16
    expect(st.phaseOn(DateTime(2026, 11, 12)), CyclePhase.lutea);
    expect(st.phaseOn(DateTime(2026, 8, 1)), isNull);
  });

  test('sin historial se usa un ciclo de 28 días', () {
    final st = CycleStatus.from([Period(DateTime(2026, 11, 1))]);
    expect(st.avgCycle, 28);
    expect(st.periodOn(DateTime(2026, 11, 5)), isNotNull, reason: 'regla en curso');
    expect(st.periodOn(DateTime(2026, 11, 20)), isNull);
  });

  test('ánimo medio por fase', () {
    final st = CycleStatus.from(periods);
    final avg = averageByPhase(st, [
      (DateTime(2026, 10, 19), 2),
      (DateTime(2026, 10, 20), 3),
      (DateTime(2026, 10, 26), 5),
    ]);
    expect(avg[CyclePhase.menstrual], 2.5);
    expect(avg.containsKey(CyclePhase.folicular), isFalse, reason: 'menos de 2 registros');
  });

  test('"me bajó" cierra la regla anterior abierta y se guarda', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await LocalStore.open();
    final c = CycleStore(store);
    await c.startPeriod(DateTime(2026, 10, 1));
    await c.startPeriod(DateTime(2026, 10, 29));
    final again = CycleStore(store);
    expect(again.periods, hasLength(2));
    expect(again.periods.first.end, DateTime(2026, 10, 5));
    expect(again.dayOn(DateTime(2026, 10, 29)).flow, 2);
    await again.setDay(DateTime(2026, 10, 30), const CycleDay(flow: 1, symptoms: {Symptom.colicos}));
    expect(CycleStore(store).dayOn(DateTime(2026, 10, 30)).symptoms, {Symptom.colicos});
  });

  testWidgets('la pantalla del ciclo se dibuja en un teléfono', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final store = await LocalStore.open();
    final now = DateTime.now();
    await CycleStore(store).startPeriod(DateTime(now.year, now.month, now.day - 40));
    await CycleStore(store).startPeriod(DateTime(now.year, now.month, now.day - 10));
    final settings = SettingsRepository(store);
    await settings.update(const AppSettings(sex: 'mujer', cycleEnabled: true));
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
      child: const MaterialApp(home: CycleScreen()),
    ));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('Día'), findsOneWidget);
    await tester.drag(find.byType(ListView).first, const Offset(0, -1500));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
