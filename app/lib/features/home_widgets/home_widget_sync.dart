import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';

import '../../core/models/plan.dart';
import '../../core/utils/format.dart';
import '../../shared/widgets/pet_avatar.dart';
import '../goals/state/rewards_service.dart';
import '../habits/state/habits_repository.dart';
import '../history/state/history_repository.dart';
import '../pet/domain/pet_items.dart';
import '../pet/state/pet_repository.dart';
import '../plans/state/plan_repository.dart';
import '../workout/state/workout_controller.dart';

/// Widgets de la pantalla de inicio (Android): "Mi día" y "Mi mascota".
///
/// La app guarda los datos de toda la semana; el widget elige el día de hoy por su cuenta,
/// así sigue correcto después de medianoche aunque no abras la app.
const dayWidgetAndroid = 'com.fitmakyp.fitmakyp.DayWidgetProvider';
const petWidgetAndroid = 'com.fitmakyp.fitmakyp.PetWidgetProvider';
const petOnlyWidgetAndroid = 'com.fitmakyp.fitmakyp.PetOnlyWidgetProvider';

/// Enlaces que abren los widgets al tocarlos.
const widgetUriTrain = 'fitmakyp://entrenar';
const widgetUriPet = 'fitmakyp://mascota';

String _date(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Datos (todos texto) que leen los widgets. Lógica pura.
Map<String, String> homeWidgetData({
  required DateTime now,
  required WorkoutPlan plan,
  required Set<DateTime> trainedDates,
  required bool sessionInProgress,
  required int waterGlasses,
  required int waterGoal,
  required int streak,
  required int bestStreak,
  required String petName,
  required int level,
}) {
  final trained = trainedDates.map(dateOnly).toList()..sort();
  final out = <String, String>{
    'fm_trained_date': trained.isEmpty ? '' : _date(trained.last),
    'fm_active_date': sessionInProgress ? _date(now) : '',
    'fm_water_date': _date(now),
    'fm_water_glasses': '$waterGlasses',
    'fm_water_goal': '$waterGoal',
    'fm_streak': '$streak',
    'fm_best': '$bestStreak',
    'fm_pet_name': petName.trim().isEmpty ? 'Tu mascota' : petName.trim(),
    'fm_level': '$level',
  };
  for (var w = 1; w <= 7; w++) {
    final d = plan.dayForWeekday(w);
    final training = d != null && d.isTraining && d.activeExercises.isNotEmpty;
    final ex = training ? d.activeExercises : const <WorkoutExercise>[];
    final sets = ex.fold<int>(0, (a, e) => a + e.sets);
    out['fm_day_title_$w'] = training ? d.title : 'Descanso';
    out['fm_day_info_$w'] = training ? '${ex.length} ${ex.length == 1 ? 'ejercicio' : 'ejercicios'} · $sets series' : '';
  }
  return out;
}

class HomeWidgetSync {
  HomeWidgetSync({
    required this.plans,
    required this.history,
    required this.habits,
    required this.pet,
    required this.workout,
    required this.rewards,
  }) {
    for (final l in _listenables) {
      l.addListener(_schedule);
    }
    _schedule();
  }

  final PlanRepository plans;
  final HistoryRepository history;
  final HabitsRepository habits;
  final PetRepository pet;
  final WorkoutController workout;
  final RewardsService rewards;

  Timer? _debounce;
  PetLook? _renderedLook;

  List<Listenable> get _listenables => [plans, history, habits, pet, workout, rewards];

  static bool get supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  void _schedule() {
    if (!supported) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), sync);
  }

  /// Suma a la app los vasos de agua tocados en el widget ("+💧").
  static Future<void> takeWidgetWater(HabitsRepository habits) async {
    if (!supported) return;
    try {
      final m = await const MethodChannel('fitmakyp/launch').invokeMapMethod<String, int>('takeWater');
      for (final e in (m ?? const <String, int>{}).entries) {
        final d = DateTime.tryParse(e.key);
        if (d != null && e.value > 0) await habits.addGlass(d, e.value);
      }
    } on PlatformException catch (e) {
      debugPrint('Agua del widget: $e');
    } on MissingPluginException {
      // Pruebas o plataformas sin el canal.
    }
  }

  Future<void> sync() async {
    if (!supported) return;
    // Primero recoger lo tocado en el widget, para no pisarlo con un número viejo.
    await takeWidgetWater(habits);
    try {
      final now = DateTime.now();
      final streak = history.streak(plans.trainingWeekdays);
      final data = homeWidgetData(
        now: now,
        plan: plans.active,
        trainedDates: history.trainedDates,
        sessionInProgress: workout.session != null,
        waterGlasses: habits.glasses(now),
        waterGoal: habits.settings.waterGoalGlasses,
        streak: streak.current,
        bestStreak: streak.best,
        petName: pet.name,
        level: rewards.level,
      );
      for (final e in data.entries) {
        await HomeWidget.saveWidgetData<String>(e.key, e.value);
      }
      if (_renderedLook != pet.look) {
        await _renderPet(pet.look);
        _renderedLook = pet.look;
      }
      await HomeWidget.updateWidget(qualifiedAndroidName: dayWidgetAndroid);
      await HomeWidget.updateWidget(qualifiedAndroidName: petWidgetAndroid);
      await HomeWidget.updateWidget(qualifiedAndroidName: petOnlyWidgetAndroid);
    } catch (e) {
      debugPrint('Widgets de inicio: $e');
    }
  }

  /// Dibuja la mascota (con su ropa) en tres ánimos; el widget elige cuál mostrar.
  Future<void> _renderPet(PetLook look) async {
    for (final (key, mood) in [
      ('fm_pet_img_happy', PetMood.happy),
      ('fm_pet_img_motivating', PetMood.motivating),
      ('fm_pet_img_resting', PetMood.resting),
    ]) {
      await HomeWidget.renderFlutterWidget(
        TickerMode(
          enabled: false,
          child: MediaQuery(
            data: const MediaQueryData(),
            child: PetAvatar(mood: mood, size: 150, look: look),
          ),
        ),
        key: key,
        logicalSize: const Size(170, 170),
      );
    }
  }

  void dispose() {
    _debounce?.cancel();
    for (final l in _listenables) {
      l.removeListener(_schedule);
    }
  }
}
