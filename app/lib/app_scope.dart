import 'package:flutter/widgets.dart';

import 'core/storage/local_store.dart';
import 'features/evolution/state/body_repository.dart';
import 'features/goals/state/goals_repository.dart';
import 'features/goals/state/rewards_service.dart';
import 'features/habits/state/habits_repository.dart';
import 'features/history/state/history_repository.dart';
import 'features/library/state/library_repository.dart';
import 'features/pet/state/pet_repository.dart';
import 'features/plans/state/plan_repository.dart';
import 'features/settings/state/settings_repository.dart';
import 'features/workout/state/workout_controller.dart';

/// Da acceso a los servicios de la app desde cualquier pantalla.
class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.store,
    required this.settings,
    required this.library,
    required this.plans,
    required this.history,
    required this.workout,
    required this.body,
    required this.goals,
    required this.pet,
    required this.rewards,
    required this.habits,
    this.onRestart,
    required super.child,
  });

  final LocalStore store;
  final SettingsRepository settings;
  final LibraryRepository library;
  final PlanRepository plans;
  final HistoryRepository history;
  final WorkoutController workout;
  final BodyRepository body;
  final GoalsRepository goals;
  final PetRepository pet;
  final RewardsService rewards;
  final HabitsRepository habits;

  /// Vuelve a cargar todos los datos (tras importar una copia de seguridad).
  final Future<void> Function()? onRestart;

  static AppScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope no encontrado');
    return scope!;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) => !identical(oldWidget.store, store) || !identical(oldWidget.workout, workout);
}
