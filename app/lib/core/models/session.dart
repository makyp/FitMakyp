import 'exercise.dart';

/// Estados persistidos de la máquina de entrenamiento.
/// SET_COMPLETED, NEXT_SET y NEXT_EXERCISE son transiciones instantáneas:
/// se modelan como eventos en `workout_machine.dart`, no como estados guardados.
enum SessionStatus { ready, exercise, resting, completed }

enum SetResult { completed, partial }

class ExerciseSetLog {
  const ExerciseSetLog({
    required this.setNumber,
    required this.result,
    this.repsDone,
    this.weightKg,
    required this.finishedAt,
  });

  final int setNumber;
  final SetResult result;
  final int? repsDone;

  /// Peso usado (kg). Null = sin peso / peso corporal.
  final double? weightKg;
  final DateTime finishedAt;

  Map<String, dynamic> toJson() => {
        'setNumber': setNumber,
        'result': result.name,
        'repsDone': repsDone,
        if (weightKg != null) 'weightKg': weightKg,
        'finishedAt': finishedAt.toIso8601String(),
      };

  factory ExerciseSetLog.fromJson(Map<String, dynamic> j) => ExerciseSetLog(
        setNumber: j['setNumber'] as int,
        result: SetResult.values.byName(j['result'] as String),
        repsDone: j['repsDone'] as int?,
        weightKg: (j['weightKg'] as num?)?.toDouble(),
        finishedAt: DateTime.parse(j['finishedAt'] as String),
      );
}

/// Copia del ejercicio al empezar: si luego se edita la rutina, el historial no cambia.
class SessionExercise {
  const SessionExercise({
    required this.workoutExerciseId,
    required this.exerciseId,
    required this.name,
    required this.plannedSets,
    required this.target,
    required this.restSeconds,
    this.sets = const [],
    this.skipped = false,
  });

  final String workoutExerciseId;
  final String exerciseId;
  final String name;
  final int plannedSets;
  final SetTarget target;
  final int restSeconds;
  final List<ExerciseSetLog> sets;
  final bool skipped;

  SessionExercise copyWith({List<ExerciseSetLog>? sets, bool? skipped}) => SessionExercise(
        workoutExerciseId: workoutExerciseId,
        exerciseId: exerciseId,
        name: name,
        plannedSets: plannedSets,
        target: target,
        restSeconds: restSeconds,
        sets: sets ?? this.sets,
        skipped: skipped ?? this.skipped,
      );

  Map<String, dynamic> toJson() => {
        'workoutExerciseId': workoutExerciseId,
        'exerciseId': exerciseId,
        'name': name,
        'plannedSets': plannedSets,
        'target': target.toJson(),
        'restSeconds': restSeconds,
        'sets': sets.map((s) => s.toJson()).toList(),
        'skipped': skipped,
      };

  factory SessionExercise.fromJson(Map<String, dynamic> j) => SessionExercise(
        workoutExerciseId: j['workoutExerciseId'] as String,
        exerciseId: j['exerciseId'] as String,
        name: j['name'] as String,
        plannedSets: j['plannedSets'] as int,
        target: SetTarget.fromJson(j['target'] as Map<String, dynamic>),
        restSeconds: j['restSeconds'] as int,
        sets: [for (final s in j['sets'] as List) ExerciseSetLog.fromJson(s as Map<String, dynamic>)],
        skipped: (j['skipped'] as bool?) ?? false,
      );
}

/// Descanso en curso. Se guarda la hora de fin (no un contador) para sobrevivir a cierres de la app.
class RestState {
  const RestState({required this.totalSeconds, required this.endsAt, this.pausedRemainingMs});

  final int totalSeconds;
  final DateTime endsAt;

  /// Si el descanso está en pausa, ms restantes congelados.
  final int? pausedRemainingMs;

  bool get isPaused => pausedRemainingMs != null;

  Duration remaining(DateTime now) {
    if (pausedRemainingMs != null) return Duration(milliseconds: pausedRemainingMs!);
    final d = endsAt.difference(now);
    return d.isNegative ? Duration.zero : d;
  }

  Map<String, dynamic> toJson() => {
        'totalSeconds': totalSeconds,
        'endsAt': endsAt.toIso8601String(),
        'pausedRemainingMs': pausedRemainingMs,
      };

  factory RestState.fromJson(Map<String, dynamic> j) => RestState(
        totalSeconds: j['totalSeconds'] as int,
        endsAt: DateTime.parse(j['endsAt'] as String),
        pausedRemainingMs: j['pausedRemainingMs'] as int?,
      );
}

class WorkoutSession {
  const WorkoutSession({
    required this.id,
    required this.planId,
    required this.dayId,
    required this.dayTitle,
    required this.status,
    required this.exercises,
    this.currentExerciseIndex = 0,
    this.currentSet = 1,
    this.rest,
    this.pausedAt,
    this.pausedMs = 0,
    required this.startedAt,
    this.finishedAt,
    this.finishedEarly = false,
    this.warmup,
    this.cooldown,
  });

  final String id;
  final String planId;
  final String dayId;
  final String dayTitle;
  final SessionStatus status;
  final List<SessionExercise> exercises;
  final int currentExerciseIndex;

  /// Serie en curso (empieza en 1).
  final int currentSet;
  final RestState? rest;

  /// Pausa general del entrenamiento.
  final DateTime? pausedAt;

  /// Tiempo acumulado en pausa (no cuenta como duración).
  final int pausedMs;
  final DateTime startedAt;
  final DateTime? finishedAt;
  final bool finishedEarly;

  /// Calentamiento y estiramientos: 'done', 'alreadyDone', 'skipped' o null (sin decidir).
  final String? warmup;
  final String? cooldown;

  bool get isPaused => pausedAt != null;
  SessionExercise? get currentExercise =>
      currentExerciseIndex < exercises.length ? exercises[currentExerciseIndex] : null;

  int get completedSets => exercises.fold(0, (a, e) => a + e.sets.length);
  int get plannedSets => exercises.fold(0, (a, e) => a + e.plannedSets);

  Duration activeDuration(DateTime now) {
    final end = finishedAt ?? pausedAt ?? now;
    return end.difference(startedAt) - Duration(milliseconds: pausedMs);
  }

  WorkoutSession copyWith({
    SessionStatus? status,
    List<SessionExercise>? exercises,
    int? currentExerciseIndex,
    int? currentSet,
    RestState? rest,
    bool clearRest = false,
    DateTime? pausedAt,
    bool clearPausedAt = false,
    int? pausedMs,
    DateTime? startedAt,
    DateTime? finishedAt,
    bool? finishedEarly,
    String? warmup,
    String? cooldown,
  }) =>
      WorkoutSession(
        id: id,
        planId: planId,
        dayId: dayId,
        dayTitle: dayTitle,
        status: status ?? this.status,
        exercises: exercises ?? this.exercises,
        currentExerciseIndex: currentExerciseIndex ?? this.currentExerciseIndex,
        currentSet: currentSet ?? this.currentSet,
        rest: clearRest ? null : (rest ?? this.rest),
        pausedAt: clearPausedAt ? null : (pausedAt ?? this.pausedAt),
        pausedMs: pausedMs ?? this.pausedMs,
        startedAt: startedAt ?? this.startedAt,
        finishedAt: finishedAt ?? this.finishedAt,
        finishedEarly: finishedEarly ?? this.finishedEarly,
        warmup: warmup ?? this.warmup,
        cooldown: cooldown ?? this.cooldown,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'planId': planId,
        'dayId': dayId,
        'dayTitle': dayTitle,
        'status': status.name,
        'exercises': exercises.map((e) => e.toJson()).toList(),
        'currentExerciseIndex': currentExerciseIndex,
        'currentSet': currentSet,
        'rest': rest?.toJson(),
        'pausedAt': pausedAt?.toIso8601String(),
        'pausedMs': pausedMs,
        'startedAt': startedAt.toIso8601String(),
        'finishedAt': finishedAt?.toIso8601String(),
        'finishedEarly': finishedEarly,
        if (warmup != null) 'warmup': warmup,
        if (cooldown != null) 'cooldown': cooldown,
      };

  factory WorkoutSession.fromJson(Map<String, dynamic> j) => WorkoutSession(
        id: j['id'] as String,
        planId: j['planId'] as String,
        dayId: j['dayId'] as String,
        dayTitle: j['dayTitle'] as String,
        status: SessionStatus.values.byName(j['status'] as String),
        exercises: [for (final e in j['exercises'] as List) SessionExercise.fromJson(e as Map<String, dynamic>)],
        currentExerciseIndex: j['currentExerciseIndex'] as int,
        currentSet: j['currentSet'] as int,
        rest: j['rest'] == null ? null : RestState.fromJson(j['rest'] as Map<String, dynamic>),
        pausedAt: j['pausedAt'] == null ? null : DateTime.parse(j['pausedAt'] as String),
        pausedMs: (j['pausedMs'] as int?) ?? 0,
        startedAt: DateTime.parse(j['startedAt'] as String),
        finishedAt: j['finishedAt'] == null ? null : DateTime.parse(j['finishedAt'] as String),
        finishedEarly: (j['finishedEarly'] as bool?) ?? false,
        warmup: j['warmup'] as String?,
        cooldown: j['cooldown'] as String?,
      );
}
