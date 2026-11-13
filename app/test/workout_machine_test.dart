import 'package:fitmakyp/core/models/exercise.dart';
import 'package:fitmakyp/core/models/plan.dart';
import 'package:fitmakyp/core/models/session.dart';
import 'package:fitmakyp/features/history/domain/streak.dart';
import 'package:fitmakyp/features/workout/domain/workout_machine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final t0 = DateTime(2026, 11, 9, 18);

  WorkoutSession newSession({int rest = 120}) => createSession(
        id: 's1',
        planId: 'p',
        day: WorkoutDay(
          id: 'd1',
          weekday: 1,
          kind: DayKind.training,
          title: 'Test',
          exercises: [
            WorkoutExercise(id: 'a', exerciseId: 'ex_a', sets: 2, target: const SetTarget.reps(12), restSeconds: rest),
            const WorkoutExercise(id: 'b', exerciseId: 'ex_b', sets: 1, target: SetTarget.seconds(30)),
            const WorkoutExercise(id: 'off', exerciseId: 'ex_off', sets: 3, target: SetTarget.reps(10), enabled: false),
          ],
        ),
        exerciseName: (id) => id,
        defaultRestSeconds: 90,
        now: t0,
      );

  test('omite ejercicios desactivados y usa el descanso por defecto', () {
    final s = newSession();
    expect(s.exercises.map((e) => e.exerciseId), ['ex_a', 'ex_b']);
    expect(s.exercises[1].restSeconds, 90);
    expect(s.status, SessionStatus.ready);
  });

  test('flujo completo READY → EXERCISE → RESTING → … → COMPLETED', () {
    var s = reduce(newSession(), const StartWorkout(), t0.add(const Duration(minutes: 3)));
    expect(s.status, SessionStatus.exercise);
    expect(s.startedAt, t0.add(const Duration(minutes: 3)), reason: 'la duración empieza al pulsar Empezar');

    s = reduce(s, const CompleteSet(), t0);
    expect(s.status, SessionStatus.resting);
    expect(s.currentSet, 2); // NEXT_SET
    expect(s.rest!.endsAt, t0.add(const Duration(seconds: 120)));

    s = reduce(s, const FinishRest(), t0);
    s = reduce(s, const CompleteSet(), t0);
    expect(s.status, SessionStatus.resting);
    expect(s.currentExerciseIndex, 1); // NEXT_EXERCISE
    expect(s.currentSet, 1);

    s = reduce(s, const FinishRest(), t0);
    s = reduce(s, const CompleteSet(), t0.add(const Duration(minutes: 10)));
    expect(s.status, SessionStatus.completed);
    expect(s.completedSets, 3);
    expect(s.finishedEarly, isFalse);
  });

  test('pausa congela el descanso y no cuenta en la duración', () {
    var s = reduce(newSession(), const StartWorkout(), t0);
    s = reduce(s, const CompleteSet(), t0);
    s = reduce(s, const PauseWorkout(), t0.add(const Duration(seconds: 20)));
    expect(s.rest!.remaining(t0.add(const Duration(hours: 1))), const Duration(seconds: 100));
    // Mientras está en pausa se ignoran otros eventos.
    expect(identical(reduce(s, const CompleteSet(), t0), s), isTrue);

    s = reduce(s, const ResumeWorkout(), t0.add(const Duration(seconds: 80)));
    expect(s.pausedMs, 60000);
    expect(s.rest!.remaining(t0.add(const Duration(seconds: 80))), const Duration(seconds: 100));
  });

  test('ajustar descanso suma y resta sin bajar de cero', () {
    var s = reduce(newSession(), const StartWorkout(), t0);
    s = reduce(s, const CompleteSet(), t0);
    s = reduce(s, const AdjustRest(15), t0);
    expect(s.rest!.remaining(t0), const Duration(seconds: 135));
    s = reduce(s, const AdjustRest(-500), t0);
    expect(s.rest!.remaining(t0), Duration.zero);
  });

  test('omitir ejercicio y serie incompleta', () {
    var s = reduce(newSession(), const StartWorkout(), t0);
    s = reduce(s, const CompleteSet(result: SetResult.partial, repsDone: 8), t0);
    s = reduce(s, const FinishRest(), t0);
    s = reduce(s, const SkipExercise(), t0);
    expect(s.exercises[0].skipped, isTrue);
    expect(s.exercises[0].sets.single.repsDone, 8);
    expect(s.currentExerciseIndex, 1);
    expect(s.status, SessionStatus.exercise);
  });

  test('terminar antes guarda lo hecho', () {
    var s = reduce(newSession(), const StartWorkout(), t0);
    s = reduce(s, const CompleteSet(), t0);
    s = reduce(s, const FinishEarly(), t0);
    expect(s.status, SessionStatus.completed);
    expect(s.finishedEarly, isTrue);
    expect(s.completedSets, 1);
  });

  test('sesión sobrevive a guardar y cargar (JSON)', () {
    var s = reduce(newSession(), const StartWorkout(), t0);
    s = reduce(s, const CompleteSet(), t0);
    final restored = WorkoutSession.fromJson(s.toJson());
    expect(restored.status, SessionStatus.resting);
    expect(restored.rest!.endsAt, s.rest!.endsAt);
    expect(restored.exercises[0].sets.length, 1);
  });

  group('rachas', () {
    const lunesAViernes = {1, 2, 3, 4, 5};

    test('el fin de semana de descanso no rompe la racha', () {
      // jue 5, vie 6, (sáb 7, dom 8 descanso), lun 9 nov 2026
      final r = computeStreak(
        trainedDates: {DateTime(2026, 11, 5), DateTime(2026, 11, 6), DateTime(2026, 11, 9)},
        trainingWeekdays: lunesAViernes,
        today: DateTime(2026, 11, 9, 20),
      );
      expect(r.current, 3);
    });

    test('hoy sin entrenar todavía no rompe la racha; un día programado fallado sí', () {
      final r = computeStreak(
        trainedDates: {DateTime(2026, 11, 2), DateTime(2026, 11, 4), DateTime(2026, 11, 5)},
        trainingWeekdays: lunesAViernes,
        today: DateTime(2026, 11, 6, 9), // viernes, aún no entrena
      );
      expect(r.current, 2); // falló el martes 3
      expect(r.best, 2);
    });
  });
}
