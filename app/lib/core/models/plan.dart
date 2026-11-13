import 'exercise.dart';

/// Un ejercicio dentro de un día de rutina (apunta a la biblioteca por [exerciseId]).
class WorkoutExercise {
  const WorkoutExercise({
    required this.id,
    required this.exerciseId,
    required this.sets,
    required this.target,
    this.restSeconds,
    this.notes = '',
    this.enabled = true,
  });

  final String id;
  final String exerciseId;
  final int sets;
  final SetTarget target;

  /// Descanso tras cada serie. Si es null se usa el de Ajustes.
  final int? restSeconds;
  final String notes;

  /// Desactivado temporalmente: no aparece al entrenar, pero no se borra.
  final bool enabled;

  WorkoutExercise copyWith({
    String? exerciseId,
    int? sets,
    SetTarget? target,
    int? restSeconds,
    bool clearRest = false,
    String? notes,
    bool? enabled,
  }) =>
      WorkoutExercise(
        id: id,
        exerciseId: exerciseId ?? this.exerciseId,
        sets: sets ?? this.sets,
        target: target ?? this.target,
        restSeconds: clearRest ? null : (restSeconds ?? this.restSeconds),
        notes: notes ?? this.notes,
        enabled: enabled ?? this.enabled,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'exerciseId': exerciseId,
        'sets': sets,
        'target': target.toJson(),
        'restSeconds': restSeconds,
        'notes': notes,
        'enabled': enabled,
      };

  factory WorkoutExercise.fromJson(Map<String, dynamic> j) => WorkoutExercise(
        id: j['id'] as String,
        exerciseId: j['exerciseId'] as String,
        sets: j['sets'] as int,
        target: SetTarget.fromJson(j['target'] as Map<String, dynamic>),
        restSeconds: j['restSeconds'] as int?,
        notes: (j['notes'] as String?) ?? '',
        enabled: (j['enabled'] as bool?) ?? true,
      );
}

enum DayKind { training, rest }

const weekdayNames = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];

class WorkoutDay {
  const WorkoutDay({
    required this.id,
    required this.weekday,
    required this.kind,
    required this.title,
    this.exercises = const [],
  });

  final String id;

  /// 1 = lunes … 7 = domingo (igual que DateTime.weekday).
  final int weekday;
  final DayKind kind;
  final String title;
  final List<WorkoutExercise> exercises;

  String get weekdayName => weekdayNames[weekday - 1];
  bool get isTraining => kind == DayKind.training;
  List<WorkoutExercise> get activeExercises => exercises.where((e) => e.enabled).toList();

  WorkoutDay copyWith({int? weekday, DayKind? kind, String? title, List<WorkoutExercise>? exercises}) => WorkoutDay(
        id: id,
        weekday: weekday ?? this.weekday,
        kind: kind ?? this.kind,
        title: title ?? this.title,
        exercises: exercises ?? this.exercises,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'weekday': weekday,
        'kind': kind.name,
        'title': title,
        'exercises': exercises.map((e) => e.toJson()).toList(),
      };

  factory WorkoutDay.fromJson(Map<String, dynamic> j) => WorkoutDay(
        id: j['id'] as String,
        weekday: j['weekday'] as int,
        kind: DayKind.values.byName(j['kind'] as String),
        title: j['title'] as String,
        exercises: [for (final e in j['exercises'] as List) WorkoutExercise.fromJson(e as Map<String, dynamic>)],
      );
}

class WorkoutPlan {
  const WorkoutPlan({
    required this.id,
    required this.name,
    required this.days,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final List<WorkoutDay> days;
  final DateTime createdAt;
  final DateTime updatedAt;

  WorkoutDay? dayForWeekday(int weekday) {
    for (final d in days) {
      if (d.weekday == weekday) return d;
    }
    return null;
  }

  WorkoutPlan copyWith({String? name, List<WorkoutDay>? days}) => WorkoutPlan(
        id: id,
        name: name ?? this.name,
        days: days ?? this.days,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'days': days.map((d) => d.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory WorkoutPlan.fromJson(Map<String, dynamic> j) => WorkoutPlan(
        id: j['id'] as String,
        name: j['name'] as String,
        days: [for (final d in j['days'] as List) WorkoutDay.fromJson(d as Map<String, dynamic>)],
        createdAt: DateTime.parse(j['createdAt'] as String),
        updatedAt: DateTime.parse(j['updatedAt'] as String),
      );
}
