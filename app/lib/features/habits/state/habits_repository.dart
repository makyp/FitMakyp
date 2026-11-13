import 'package:flutter/foundation.dart';

import '../../../core/models/habits.dart';
import '../domain/hand_portions.dart';
import '../../../core/storage/local_store.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/ids.dart';

/// Agua, comidas y hábitos diarios.
class HabitsRepository extends ChangeNotifier {
  HabitsRepository(this._store) {
    final w = _store.readJson(_waterKey);
    if (w is Map<String, dynamic>) _water = {for (final e in w.entries) e.key: e.value as int};
    final m = _store.readJson(_mealsKey);
    if (m is List) _meals = [for (final x in m) MealEntry.fromJson(x as Map<String, dynamic>)];
    final h = _store.readJson(_habitsKey);
    if (h is List) _habits = [for (final x in h) HabitDef.fromJson(x as Map<String, dynamic>)];
    final d = _store.readJson(_doneKey);
    if (d is Map<String, dynamic>) _done = {for (final e in d.entries) e.key: Set<String>.from(e.value as List)};
    final s = _store.readJson(_settingsKey);
    if (s is Map<String, dynamic>) _settings = HabitsSettings.fromJson(s);
  }

  static const _waterKey = 'water';
  static const _mealsKey = 'meals';
  static const _habitsKey = 'habits';
  static const _doneKey = 'habitsDone';
  static const _settingsKey = 'habitsSettings';

  final LocalStore _store;
  Map<String, int> _water = {};
  List<MealEntry> _meals = [];
  List<HabitDef> _habits = List.of(defaultHabits);
  Map<String, Set<String>> _done = {};
  HabitsSettings _settings = const HabitsSettings();

  static String dayKey(DateTime d) {
    final x = dateOnly(d);
    return '${x.year}-${x.month.toString().padLeft(2, '0')}-${x.day.toString().padLeft(2, '0')}';
  }

  HabitsSettings get settings => _settings;

  // ---------- Agua ----------
  int glasses(DateTime day) => _water[dayKey(day)] ?? 0;
  bool waterGoalMet(DateTime day) => glasses(day) >= _settings.waterGoalGlasses;

  /// Días en los que se cumplió la meta de agua.
  /// Días con al menos una comida apuntada.
  Set<DateTime> get mealDays => {for (final m in _meals) dateOnly(m.at)};

  Set<DateTime> get waterGoalDays => {
        for (final e in _water.entries)
          if (e.value >= _settings.waterGoalGlasses) DateTime.parse(e.key),
      };

  Future<void> addGlass(DateTime day, [int delta = 1]) async {
    final k = dayKey(day);
    _water[k] = ((_water[k] ?? 0) + delta).clamp(0, 30);
    notifyListeners();
    await _store.writeJson(_waterKey, _water);
  }

  // ---------- Comidas ----------
  List<MealEntry> mealsOn(DateTime day) =>
      _meals.where((m) => dateOnly(m.at) == dateOnly(day)).toList()..sort((a, b) => a.at.compareTo(b.at));

  /// Comidas con foto, de la más reciente a la más antigua.
  List<MealEntry> get recentWithPhotos =>
      _meals.where((m) => m.photoId != null).toList()..sort((a, b) => b.at.compareTo(a.at));

  /// Fotos de comidas (para la copia de seguridad).
  Set<String> get mealPhotoIds => {for (final m in _meals) ?m.photoId};

  int kcalOn(DateTime day) => mealsOn(day).fold(0, (a, m) => a + (m.kcal ?? 0));
  int proteinOn(DateTime day) => mealsOn(day).fold(0, (a, m) => a + (m.protein ?? 0));

  /// Porciones con la mano del día (solo de las comidas registradas así).
  HandPortions portionsOn(DateTime day) =>
      mealsOn(day).fold(const HandPortions(), (a, m) => m.portions == null ? a : a + m.portions!);

  /// Comidas distintas recientes, para repetirlas con un toque.
  List<MealEntry> get recentMeals {
    final seen = <String>{};
    final out = <MealEntry>[];
    for (final m in [..._meals]..sort((a, b) => b.at.compareTo(a.at))) {
      if (seen.add(m.description.toLowerCase())) out.add(m);
      if (out.length >= 8) break;
    }
    return out;
  }

  Future<void> saveMeal({
    String? id,
    required DateTime at,
    required MealType type,
    required String description,
    int? kcal,
    int? protein,
    HandPortions? portions,
    String? photoId,
  }) async {
    final meal = MealEntry(
      id: id ?? newId('meal'),
      at: at,
      type: type,
      description: description,
      kcal: kcal,
      protein: protein,
      portions: portions,
      photoId: photoId,
    );
    _meals.removeWhere((m) => m.id == meal.id);
    _meals.add(meal);
    notifyListeners();
    await _persistMeals();
  }

  Future<void> deleteMeal(String id) async {
    _meals.removeWhere((m) => m.id == id);
    notifyListeners();
    await _persistMeals();
  }

  Future<void> _persistMeals() => _store.writeJson(_mealsKey, _meals.map((m) => m.toJson()).toList());

  // ---------- Hábitos ----------
  List<HabitDef> get habits => List.unmodifiable(_habits);
  List<HabitDef> get activeHabits => _habits.where((h) => h.active).toList();

  bool isDone(String habitId, DateTime day) => _done[dayKey(day)]?.contains(habitId) ?? false;

  /// Días en los que se completaron todos los hábitos activos.
  Set<DateTime> get allHabitsDays {
    final ids = {for (final h in activeHabits) h.id};
    if (ids.isEmpty) return {};
    return {
      for (final e in _done.entries)
        if (e.value.containsAll(ids)) DateTime.parse(e.key),
    };
  }

  Future<void> toggleHabit(String habitId, DateTime day) async {
    final set = _done.putIfAbsent(dayKey(day), () => <String>{});
    set.contains(habitId) ? set.remove(habitId) : set.add(habitId);
    notifyListeners();
    await _store.writeJson(_doneKey, {for (final e in _done.entries) e.key: e.value.toList()});
  }

  Future<void> saveHabit(HabitDef h) async {
    final i = _habits.indexWhere((x) => x.id == h.id);
    i >= 0 ? _habits[i] = h : _habits.add(h);
    notifyListeners();
    await _store.writeJson(_habitsKey, _habits.map((x) => x.toJson()).toList());
  }

  Future<void> removeHabit(String id) async {
    _habits.removeWhere((h) => h.id == id);
    notifyListeners();
    await _store.writeJson(_habitsKey, _habits.map((x) => x.toJson()).toList());
  }

  Future<void> updateSettings(HabitsSettings s) async {
    _settings = s;
    notifyListeners();
    await _store.writeJson(_settingsKey, s.toJson());
  }
}
