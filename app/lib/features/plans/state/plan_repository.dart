import 'package:flutter/foundation.dart';

import '../../../core/data/seed_plan.dart';
import '../../../core/models/plan.dart';
import '../../../core/storage/local_store.dart';

/// Rutinas guardadas. El modelo ya admite varias; la interfaz edita la activa.
class PlanRepository extends ChangeNotifier {
  PlanRepository(this._store) {
    final raw = _store.readJson(_plansKey);
    if (raw is List && raw.isNotEmpty) {
      _plans = [for (final p in raw) WorkoutPlan.fromJson(p as Map<String, dynamic>)];
      _activeId = (_store.readJson(_activeKey) as String?) ?? _plans.first.id;
    } else {
      final seed = buildSeedPlan();
      _plans = [seed];
      _activeId = seed.id;
      _persist();
    }
  }

  static const _plansKey = 'plans';
  static const _activeKey = 'activePlanId';
  final LocalStore _store;
  late List<WorkoutPlan> _plans;
  late String _activeId;

  List<WorkoutPlan> get plans => List.unmodifiable(_plans);

  WorkoutPlan get active => _plans.firstWhere((p) => p.id == _activeId, orElse: () => _plans.first);

  WorkoutDay? dayById(String dayId) {
    for (final d in active.days) {
      if (d.id == dayId) return d;
    }
    return null;
  }

  WorkoutDay? get today => active.dayForWeekday(DateTime.now().weekday);

  /// Días de la semana (1-7) en los que hay entrenamiento programado.
  Set<int> get trainingWeekdays => {for (final d in active.days) if (d.isTraining) d.weekday};

  Future<void> updateDay(WorkoutDay day) async {
    final plan = active;
    final days = [for (final d in plan.days) d.id == day.id ? day : d];
    await _replace(plan.copyWith(days: days));
  }

  /// Guarda una rutina nueva y la deja como activa (las anteriores se conservan).
  Future<void> addAndActivate(WorkoutPlan plan) async {
    _plans = [..._plans, plan];
    _activeId = plan.id;
    notifyListeners();
    await _persist();
  }

  Future<void> setActive(String id) async {
    if (!_plans.any((p) => p.id == id)) return;
    _activeId = id;
    notifyListeners();
    await _persist();
  }

  /// Borra una rutina que no sea la activa.
  Future<void> delete(String id) async {
    if (id == _activeId || _plans.length < 2) return;
    _plans = [for (final p in _plans) if (p.id != id) p];
    notifyListeners();
    await _persist();
  }

  Future<void> rename(String id, String name) async {
    final p = _plans.where((x) => x.id == id).firstOrNull;
    if (p == null || name.trim().isEmpty) return;
    await _replace(p.copyWith(name: name.trim()));
  }

  /// Agrega un ejercicio al final de un día de la rutina activa.
  Future<void> addExerciseToDay(String dayId, WorkoutExercise we) async {
    final d = dayById(dayId);
    if (d == null) return;
    await updateDay(d.copyWith(kind: DayKind.training, exercises: [...d.exercises, we]));
  }

  Future<void> _replace(WorkoutPlan plan) async {
    _plans = [for (final p in _plans) p.id == plan.id ? plan : p];
    notifyListeners();
    await _persist();
  }

  Future<void> _persist() async {
    await _store.writeJson(_plansKey, _plans.map((p) => p.toJson()).toList());
    await _store.writeJson(_activeKey, _activeId);
  }
}
