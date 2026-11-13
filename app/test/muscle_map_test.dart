import 'package:fitmakyp/core/models/body.dart';
import 'package:fitmakyp/core/models/exercise.dart';
import 'package:fitmakyp/core/models/session.dart';
import 'package:fitmakyp/features/evolution/domain/muscle_map.dart';
import 'package:fitmakyp/features/evolution/domain/progress_analysis.dart';
import 'package:fitmakyp/features/evolution/ui/body_map.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

WorkoutSession _s(String id, DateTime at, String exId, int sets) => WorkoutSession(
      id: id,
      planId: 'p',
      dayId: 'd',
      dayTitle: 'Día',
      status: SessionStatus.completed,
      startedAt: at,
      finishedAt: at.add(const Duration(minutes: 40)),
      exercises: [
        SessionExercise(
          workoutExerciseId: 'w',
          exerciseId: exId,
          name: exId,
          plannedSets: sets,
          target: const SetTarget.reps(10),
          restSeconds: 60,
          sets: [for (var i = 0; i < sets; i++) ExerciseSetLog(setNumber: i + 1, result: SetResult.completed, finishedAt: at)],
        ),
      ],
    );

Exercise _ex(String id, MuscleGroup m, [List<MuscleGroup> sec = const []]) => Exercise(
      id: id,
      name: id,
      primaryMuscle: m,
      secondaryMuscles: sec,
      description: '',
      suggestedTarget: const SetTarget.reps(10),
    );

void main() {
  final lib = {
    'hip': _ex('hip', MuscleGroup.gluteos, [MuscleGroup.isquiotibiales]),
    'plancha': _ex('plancha', MuscleGroup.core),
  };
  final now = DateTime(2026, 11, 10, 20);
  final sessions = [
    _s('1', DateTime(2026, 11, 9, 18), 'hip', 4),
    _s('2', DateTime(2026, 11, 6, 18), 'hip', 3),
    _s('3', DateTime(2026, 11, 7, 18), 'plancha', 2),
    _s('4', DateTime(2026, 10, 1, 18), 'hip', 10),
  ];

  test('series por músculo: principal 1, secundario 0,5, dentro del periodo', () {
    final m = trainingMap(sessions, (id) => lib[id], TrainingPeriod.semana, now);
    expect(m.setsOf(MuscleGroup.gluteos), 7);
    expect(m.setsOf(MuscleGroup.isquiotibiales), 3.5);
    expect(m.stats[MuscleGroup.gluteos]!.sessions, 2);
    expect(m.stats[MuscleGroup.gluteos]!.last, DateTime(2026, 11, 9, 18));
    expect(m.zoneLevel(BodyZone.gluteos), TrainingLevel.bien);
    expect(m.zoneLevel(BodyZone.oblicuos), TrainingLevel.poco, reason: 'core trabaja oblicuos');
    expect(m.zoneLevel(BodyZone.pecho), TrainingLevel.nada);
    expect(m.ranking.first.muscle, MuscleGroup.gluteos);
    final all = trainingMap(sessions, (id) => lib[id], TrainingPeriod.todo, now);
    expect(all.setsOf(MuscleGroup.gluteos), 17);
  });

  test('color de zona según la medida de cada lado', () {
    final before = {Measure.musloDer: 60.0, Measure.musloIzq: 60.0};
    final after = {Measure.musloDer: 56.0, Measure.musloIzq: 59.8};
    final tr = {Measure.musloDer: Trend.reduce, Measure.musloIzq: Trend.reduce};
    expect(zoneTier(BodyZone.cuadriceps, -1, before, after, tr), ImprovementTier.morado);
    expect(zoneTier(BodyZone.cuadriceps, 1, before, after, tr), ImprovementTier.gris);
    expect(zoneTier(BodyZone.deltoides, 0, before, after, tr), isNull);
  });

  test('tocar el dibujo encuentra el músculo, frente y espalda', () {
    const size = Size(300, 600);
    final front = BodyGeometry(SilhouetteWidths(const {}), size, 165, BodyView.frente);
    final back = BodyGeometry(SilhouetteWidths(const {}), size, 165, BodyView.espalda);
    final h = 600 * 0.95, top = 600 * 0.035;
    expect(front.hit(Offset(158, top + h * 0.35))?.zone, BodyZone.abdomen);
    expect(back.hit(Offset(150 + 30, top + h * 0.51))?.zone, BodyZone.gluteos);
    // De frente, el lado izquierdo de la pantalla es el lado derecho de la persona.
    final thigh = front.hit(Offset(150 - 35, top + h * 0.63));
    expect(thigh?.zone, BodyZone.cuadriceps);
    expect(thigh?.side, -1);
    expect(front.hit(const Offset(5, 5)), isNull);
  });
}
