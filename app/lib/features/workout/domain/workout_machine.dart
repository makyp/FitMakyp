/// Máquina de estados del entrenamiento. Lógica pura: sin widgets, sin almacenamiento, sin relojes.
///
///   READY ──start──▶ EXERCISE ──completeSet──▶ (SET_COMPLETED)
///                       ▲                          │
///                       │                 ¿quedan series/ejercicios?
///                       │                    sí │            │ no
///                       │                       ▼            ▼
///                  finishRest/skipRest ◀── RESTING       COMPLETED
///      (NEXT_SET o NEXT_EXERCISE ya resueltos al entrar en el descanso)
///
/// Además: pause/resume, skipExercise y finishEarly desde cualquier estado activo.
library;

import '../../../core/models/exercise.dart';
import '../../../core/models/plan.dart';
import '../../../core/models/session.dart';

sealed class WorkoutEvent {
  const WorkoutEvent();
}

class StartWorkout extends WorkoutEvent {
  const StartWorkout();
}

class CompleteSet extends WorkoutEvent {
  const CompleteSet({this.result = SetResult.completed, this.repsDone, this.weightKg});
  final SetResult result;
  final int? repsDone;
  final double? weightKg;
}

class FinishRest extends WorkoutEvent {
  const FinishRest();
}

class AdjustRest extends WorkoutEvent {
  const AdjustRest(this.deltaSeconds);
  final int deltaSeconds;
}

class PauseWorkout extends WorkoutEvent {
  const PauseWorkout();
}

class ResumeWorkout extends WorkoutEvent {
  const ResumeWorkout();
}

class SkipExercise extends WorkoutEvent {
  const SkipExercise();
}

class FinishEarly extends WorkoutEvent {
  const FinishEarly();
}

/// Crea una sesión a partir de un día de la rutina. Copia los datos para que
/// editar la rutina después no altere el historial.
WorkoutSession createSession({
  required String id,
  required String planId,
  required WorkoutDay day,
  required String Function(String exerciseId) exerciseName,
  required int defaultRestSeconds,
  required DateTime now,
}) {
  return WorkoutSession(
    id: id,
    planId: planId,
    dayId: day.id,
    dayTitle: '${day.weekdayName} · ${day.title}',
    status: SessionStatus.ready,
    startedAt: now,
    exercises: [
      for (final we in day.activeExercises)
        SessionExercise(
          workoutExerciseId: we.id,
          exerciseId: we.exerciseId,
          name: exerciseName(we.exerciseId),
          plannedSets: we.sets,
          target: we.target,
          restSeconds: we.restSeconds ?? defaultRestSeconds,
        ),
    ],
  );
}

WorkoutSession reduce(WorkoutSession s, WorkoutEvent event, DateTime now) {
  if (s.status == SessionStatus.completed) return s;

  // Mientras está en pausa solo se puede reanudar o terminar.
  if (s.isPaused && event is! ResumeWorkout && event is! FinishEarly) return s;

  switch (event) {
    case StartWorkout():
      if (s.status != SessionStatus.ready) return s;
      if (s.exercises.isEmpty) return _complete(s, now, early: false);
      // La duración cuenta desde que se pulsa Empezar, no desde que se abre la pantalla.
      return s.copyWith(status: SessionStatus.exercise, startedAt: now);

    case CompleteSet(:final result, :final repsDone, :final weightKg):
      if (s.status != SessionStatus.exercise) return s;
      final ex = s.currentExercise!;
      final log = ExerciseSetLog(
        setNumber: s.currentSet,
        result: result,
        repsDone: repsDone,
        weightKg: weightKg,
        finishedAt: now,
      );
      final exercises = [...s.exercises];
      exercises[s.currentExerciseIndex] = ex.copyWith(sets: [...ex.sets, log]);
      final updated = s.copyWith(exercises: exercises);

      // NEXT_SET o NEXT_EXERCISE
      final int nextIndex;
      final int nextSet;
      if (s.currentSet < ex.plannedSets) {
        nextIndex = s.currentExerciseIndex;
        nextSet = s.currentSet + 1;
      } else {
        nextIndex = s.currentExerciseIndex + 1;
        nextSet = 1;
      }
      if (nextIndex >= s.exercises.length) return _complete(updated, now, early: false);

      final moved = updated.copyWith(currentExerciseIndex: nextIndex, currentSet: nextSet);
      if (ex.restSeconds <= 0) return moved.copyWith(status: SessionStatus.exercise, clearRest: true);
      return moved.copyWith(
        status: SessionStatus.resting,
        rest: RestState(totalSeconds: ex.restSeconds, endsAt: now.add(Duration(seconds: ex.restSeconds))),
      );

    case FinishRest():
      if (s.status != SessionStatus.resting) return s;
      return s.copyWith(status: SessionStatus.exercise, clearRest: true);

    case AdjustRest(:final deltaSeconds):
      final rest = s.rest;
      if (s.status != SessionStatus.resting || rest == null) return s;
      final remainingMs = rest.remaining(now).inMilliseconds + deltaSeconds * 1000;
      final clamped = remainingMs < 0 ? 0 : remainingMs;
      final total = rest.totalSeconds + deltaSeconds;
      return s.copyWith(
        rest: RestState(
          totalSeconds: total < 1 ? 1 : total,
          endsAt: now.add(Duration(milliseconds: clamped)),
        ),
      );

    case PauseWorkout():
      final rest = s.rest;
      return s.copyWith(
        pausedAt: now,
        rest: rest == null
            ? null
            : RestState(
                totalSeconds: rest.totalSeconds,
                endsAt: rest.endsAt,
                pausedRemainingMs: rest.remaining(now).inMilliseconds,
              ),
      );

    case ResumeWorkout():
      if (!s.isPaused) return s;
      final rest = s.rest;
      return s.copyWith(
        clearPausedAt: true,
        pausedMs: s.pausedMs + now.difference(s.pausedAt!).inMilliseconds,
        rest: rest == null
            ? null
            : RestState(
                totalSeconds: rest.totalSeconds,
                endsAt: now.add(Duration(milliseconds: rest.pausedRemainingMs ?? 0)),
              ),
      );

    case SkipExercise():
      if (s.status == SessionStatus.ready) return s;
      // Durante el descanso, el ejercicio "actual" es el que viene: se omite ese.
      final exercises = [...s.exercises];
      exercises[s.currentExerciseIndex] = s.currentExercise!.copyWith(skipped: true);
      final next = s.currentExerciseIndex + 1;
      final updated = s.copyWith(exercises: exercises);
      if (next >= s.exercises.length) return _complete(updated, now, early: false);
      return updated.copyWith(
        status: SessionStatus.exercise,
        currentExerciseIndex: next,
        currentSet: 1,
        clearRest: true,
      );

    case FinishEarly():
      final resumed = s.isPaused ? reduce(s, const ResumeWorkout(), now) : s;
      return _complete(resumed, now, early: true);
  }
}

WorkoutSession _complete(WorkoutSession s, DateTime now, {required bool early}) => s.copyWith(
      status: SessionStatus.completed,
      finishedAt: now,
      finishedEarly: early,
      clearRest: true,
    );

/// Etiqueta del objetivo de la serie (para resúmenes).
String targetLabel(SetTarget t) => t.label;
