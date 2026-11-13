import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/notifications/reminders.dart';
import '../../../core/storage/local_store.dart';
import '../../../core/utils/format.dart';
import '../../cycle/cycle_store.dart';
import '../../settings/state/settings_repository.dart';
import '../../evolution/state/body_repository.dart';
import '../../history/state/history_repository.dart';
import '../../pet/state/pet_repository.dart';
import '../../plans/state/plan_repository.dart';
import 'habits_repository.dart';

/// Mantiene programados los recordatorios de agua y de evaluación.
/// Se recalcula al abrir la app y cuando cambian el agua, los ajustes o los registros corporales.
class ReminderSync {
  ReminderSync({
    required this.habits,
    required this.body,
    required this.plans,
    required this.history,
    required this.pet,
    required this.reminders,
    this.store,
    this.settings,
  }) {
    for (final l in _listenables) {
      l.addListener(_schedule);
    }
    CycleStore.onChanged = _schedule;
    _schedule();
  }

  /// Para el aviso del ciclo (opcionales).
  final LocalStore? store;
  final SettingsRepository? settings;

  List<Listenable> get _listenables => [habits, body, plans, history, pet, ?settings];

  final HabitsRepository habits;
  final BodyRepository body;
  final PlanRepository plans;
  final HistoryRepository history;
  final PetRepository pet;
  final Reminders reminders;
  Timer? _debounce;

  void _schedule() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), sync);
  }

  Future<void> sync() async {
    final now = DateTime.now();
    final s = habits.settings;
    await reminders.scheduleWater(
      waterReminderTimes(now: now, settings: s, goalMetToday: habits.waterGoalMet(now)),
    );
    await reminders.scheduleEvaluation(
      evaluationReminderAt(nextEvaluation: body.nextEvaluation, now: now, enabled: s.evaluationReminder),
    );
    await reminders.scheduleWorkout(workoutReminders(
      now: now,
      settings: s,
      dayTitles: {for (final d in plans.active.days) if (d.isTraining) d.weekday: d.title},
      trainedToday: history.trainedDates.contains(dateOnly(now)),
      petName: pet.name,
    ));
    final st = store;
    final cycleOn = settings?.settings.showCycle ?? false;
    await reminders.schedulePeriod(
      st == null || !cycleOn ? null : periodReminderAt(nextStart: CycleStore(st).status.nextStart, now: now),
      daysBefore: 2,
    );
  }

  void dispose() {
    _debounce?.cancel();
    for (final l in _listenables) {
      l.removeListener(_schedule);
    }
    if (CycleStore.onChanged == _schedule) CycleStore.onChanged = null;
  }
}
