/// Hidratación, alimentación y hábitos diarios.
/// Todos los objetivos son orientativos y configurables: no son prescripciones médicas.
library;

import '../../features/habits/domain/hand_portions.dart';

enum MealType {
  desayuno('Desayuno', '🍳'),
  almuerzo('Almuerzo', '🥗'),
  cena('Cena', '🍲'),
  snack('Snack', '🍎');

  const MealType(this.label, this.emoji);
  final String label;
  final String emoji;
}

class MealEntry {
  const MealEntry({
    required this.id,
    required this.at,
    required this.type,
    required this.description,
    this.kcal,
    this.protein,
    this.portions,
    this.photoId,
  });

  final String id;
  final DateTime at;
  final MealType type;
  final String description;

  /// Aproximadas y opcionales.
  final int? kcal;
  final int? protein;

  /// Porciones con la mano (si se registró sin pesar). kcal y proteína son entonces estimadas.
  final HandPortions? portions;

  /// Foto del plato (opcional, solo en el teléfono).
  final String? photoId;

  Map<String, dynamic> toJson() => {
        'id': id,
        'at': at.toIso8601String(),
        'type': type.name,
        'description': description,
        'kcal': kcal,
        'protein': protein,
        if (portions != null) 'portions': portions!.toJson(),
        if (photoId != null) 'photoId': photoId,
      };

  factory MealEntry.fromJson(Map<String, dynamic> j) => MealEntry(
        id: j['id'] as String,
        at: DateTime.parse(j['at'] as String),
        type: MealType.values.byName(j['type'] as String),
        description: j['description'] as String,
        kcal: j['kcal'] as int?,
        protein: j['protein'] as int?,
        portions: HandPortions.fromJson(j['portions']),
        photoId: j['photoId'] as String?,
      );
}

class HabitDef {
  const HabitDef({required this.id, required this.name, this.emoji = '✨', this.active = true});
  final String id;
  final String name;
  final String emoji;
  final bool active;

  HabitDef copyWith({String? name, String? emoji, bool? active}) =>
      HabitDef(id: id, name: name ?? this.name, emoji: emoji ?? this.emoji, active: active ?? this.active);

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'emoji': emoji, 'active': active};

  factory HabitDef.fromJson(Map<String, dynamic> j) => HabitDef(
        id: j['id'] as String,
        name: j['name'] as String,
        emoji: (j['emoji'] as String?) ?? '✨',
        active: (j['active'] as bool?) ?? true,
      );
}

const defaultHabits = [
  HabitDef(id: 'h_fruta', name: 'Comer fruta o verdura', emoji: '🥦'),
  HabitDef(id: 'h_estirar', name: 'Estirar 10 minutos', emoji: '🧘'),
  HabitDef(id: 'h_caminar', name: 'Caminar 30 minutos', emoji: '🚶‍♀️'),
  HabitDef(id: 'h_dormir', name: 'Dormir 7 horas o más', emoji: '😴'),
];

class HabitsSettings {
  const HabitsSettings({
    this.waterGoalGlasses = 8,
    this.glassMl = 250,
    this.waterReminders = true,
    this.reminderStartHour = 9,
    this.reminderEndHour = 21,
    this.reminderEveryHours = 2,
    this.nutritionEnabled = true,
    this.kcalTarget = 1500,
    this.proteinTarget = 110,
    this.evaluationReminder = true,
    this.workoutReminder = true,
    this.workoutReminderHour = 18,
    this.workoutReminderMinute = 0,
  });

  final int waterGoalGlasses;
  final int glassMl;
  final bool waterReminders;
  final int reminderStartHour;
  final int reminderEndHour;
  final int reminderEveryHours;
  final bool nutritionEnabled;
  final int kcalTarget;
  final int proteinTarget;
  final bool evaluationReminder;

  /// Aviso "Es hora de entrenar" los días con entrenamiento.
  final bool workoutReminder;
  final int workoutReminderHour;
  final int workoutReminderMinute;

  /// Horas del día en las que suena el recordatorio de agua.
  List<int> get reminderHours => [
        for (var h = reminderStartHour; h <= reminderEndHour; h += reminderEveryHours.clamp(1, 12)) h,
      ];

  HabitsSettings copyWith({
    int? waterGoalGlasses,
    int? glassMl,
    bool? waterReminders,
    int? reminderStartHour,
    int? reminderEndHour,
    int? reminderEveryHours,
    bool? nutritionEnabled,
    int? kcalTarget,
    int? proteinTarget,
    bool? evaluationReminder,
    bool? workoutReminder,
    int? workoutReminderHour,
    int? workoutReminderMinute,
  }) =>
      HabitsSettings(
        waterGoalGlasses: waterGoalGlasses ?? this.waterGoalGlasses,
        glassMl: glassMl ?? this.glassMl,
        waterReminders: waterReminders ?? this.waterReminders,
        reminderStartHour: reminderStartHour ?? this.reminderStartHour,
        reminderEndHour: reminderEndHour ?? this.reminderEndHour,
        reminderEveryHours: reminderEveryHours ?? this.reminderEveryHours,
        nutritionEnabled: nutritionEnabled ?? this.nutritionEnabled,
        kcalTarget: kcalTarget ?? this.kcalTarget,
        proteinTarget: proteinTarget ?? this.proteinTarget,
        evaluationReminder: evaluationReminder ?? this.evaluationReminder,
        workoutReminder: workoutReminder ?? this.workoutReminder,
        workoutReminderHour: workoutReminderHour ?? this.workoutReminderHour,
        workoutReminderMinute: workoutReminderMinute ?? this.workoutReminderMinute,
      );

  Map<String, dynamic> toJson() => {
        'waterGoalGlasses': waterGoalGlasses,
        'glassMl': glassMl,
        'waterReminders': waterReminders,
        'reminderStartHour': reminderStartHour,
        'reminderEndHour': reminderEndHour,
        'reminderEveryHours': reminderEveryHours,
        'nutritionEnabled': nutritionEnabled,
        'kcalTarget': kcalTarget,
        'proteinTarget': proteinTarget,
        'evaluationReminder': evaluationReminder,
        'workoutReminder': workoutReminder,
        'workoutReminderHour': workoutReminderHour,
        'workoutReminderMinute': workoutReminderMinute,
      };

  factory HabitsSettings.fromJson(Map<String, dynamic> j) {
    const d = HabitsSettings();
    return HabitsSettings(
      waterGoalGlasses: (j['waterGoalGlasses'] as int?) ?? d.waterGoalGlasses,
      glassMl: (j['glassMl'] as int?) ?? d.glassMl,
      waterReminders: (j['waterReminders'] as bool?) ?? d.waterReminders,
      reminderStartHour: (j['reminderStartHour'] as int?) ?? d.reminderStartHour,
      reminderEndHour: (j['reminderEndHour'] as int?) ?? d.reminderEndHour,
      reminderEveryHours: (j['reminderEveryHours'] as int?) ?? d.reminderEveryHours,
      nutritionEnabled: (j['nutritionEnabled'] as bool?) ?? d.nutritionEnabled,
      kcalTarget: (j['kcalTarget'] as int?) ?? d.kcalTarget,
      proteinTarget: (j['proteinTarget'] as int?) ?? d.proteinTarget,
      evaluationReminder: (j['evaluationReminder'] as bool?) ?? d.evaluationReminder,
      workoutReminder: (j['workoutReminder'] as bool?) ?? d.workoutReminder,
      workoutReminderHour: (j['workoutReminderHour'] as int?) ?? d.workoutReminderHour,
      workoutReminderMinute: (j['workoutReminderMinute'] as int?) ?? d.workoutReminderMinute,
    );
  }
}
