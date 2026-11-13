import 'package:fitmakyp/core/data/seed_exercises.dart';
import 'package:fitmakyp/core/models/exercise.dart';
import 'package:fitmakyp/core/models/session.dart';
import 'package:fitmakyp/features/evolution/domain/muscle_map.dart';
import 'package:fitmakyp/features/plans/domain/ai_plan.dart';
import 'package:fitmakyp/features/workout/domain/strength.dart';
import 'package:flutter_test/flutter_test.dart';

WorkoutSession _s(String id, DateTime at, String exId, List<(int, double?)> sets,
        {SetTarget target = const SetTarget.reps(10, max: 12), int planned = 3}) =>
    WorkoutSession(
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
          name: 'Sentadilla',
          plannedSets: planned,
          target: target,
          restSeconds: 60,
          sets: [
            for (final (i, (r, w)) in sets.indexed)
              ExerciseSetLog(setNumber: i + 1, result: SetResult.completed, repsDone: r, weightKg: w, finishedAt: at),
          ],
        ),
      ],
    );

int _n = 0;
String _id(String p) => '${p}_${_n++}';

void main() {
  group('fuerza', () {
    test('el peso se guarda y se lee', () {
      final log = ExerciseSetLog(setNumber: 1, result: SetResult.completed, repsDone: 12, weightKg: 7.5, finishedAt: _epoch);
      expect(ExerciseSetLog.fromJson(log.toJson()).weightKg, 7.5);
    });

    test('sugerencia: sube peso al completar todo en el tope del rango', () {
      const target = SetTarget.reps(10, max: 12);
      final up = suggestNext([
        SetPerf(reps: 12, weight: 8, at: _epoch, sessionId: 'a'),
        SetPerf(reps: 12, weight: 8, at: _epoch, sessionId: 'a'),
        SetPerf(reps: 12, weight: 8, at: _epoch, sessionId: 'a'),
      ], target, 3)!;
      expect(up.increase, isTrue);
      expect(up.weight, 9);
      expect(up.reps, 10);

      final keep = suggestNext([
        SetPerf(reps: 12, weight: 8, at: _epoch, sessionId: 'a'),
        SetPerf(reps: 10, weight: 8, at: _epoch, sessionId: 'a'),
      ], target, 3)!;
      expect(keep.increase, isFalse);
      expect(keep.weight, 8);
      expect(suggestNext(null, const SetTarget.seconds(30), 3), isNull);
    });

    test('récords, últimas series y récord nuevo', () {
      final sessions = [
        _s('1', DateTime(2026, 11, 2), 'sentadilla', [(12, 6), (12, 6), (10, 6)]),
        _s('2', DateTime(2026, 11, 5), 'sentadilla', [(12, 8), (11, 8), (10, 8)]),
        _s('3', DateTime(2026, 11, 9), 'sentadilla', [(10, 10), (10, 10), (8, 10)]),
      ];
      final r = exerciseRecords(sessions, 'sentadilla');
      expect(r.heaviest!.weight, 10);
      expect(r.sessions, 3);
      expect(r.weightSeries.map((e) => e.$2), [6, 8, 10]);
      expect(lastPerformance(sessions, 'sentadilla', excludeSessionId: '3')!.$1.id, '2');
      expect(describeSets(setsIn(sessions[0], 'sentadilla')), '12, 12, 10 reps · 6 kg');
      expect(describeSets(setsIn(sessions[2], 'sentadilla').take(2).toList()), '2 × 10 · 10 kg');
      expect(newRecordsIn(sessions[2], sessions).single.text, contains('10 kg'));
      expect(newRecordsIn(sessions[0], sessions), isEmpty, reason: 'la primera vez no es récord');
    });
  });

  group('rutina con IA (copiar y pegar)', () {
    final library = seedExercises;

    test('la pregunta incluye los ejercicios disponibles y el formato', () {
      final p = buildAiPrompt(
        const AiPlanRequest(
          goal: AiGoal.gluteosPiernas,
          weekdays: {1, 3, 5},
          minutes: 45,
          level: AiLevel.principiante,
          equipment: {Equipment.mancuernas},
          focus: {MuscleGroup.isquiotibiales},
          notes: 'rodilla sensible',
        ),
        library,
      );
      expect(p, contains('lunes, miércoles, viernes'));
      expect(p, contains('Isquiotibiales'));
      expect(p, contains('rodilla sensible'));
      expect(p, contains('"dias"'));
      expect(p, isNot(contains('bicicleta_estatica |')), reason: 'sin bicicleta no se ofrece');
    });

    test('lee la respuesta con texto y ```json alrededor', () {
      final first = library.first;
      final text = '''
¡Claro! Aquí tienes tu rutina:
```json
{"nombre": "Piernas fuertes", "dias": [
  {"dia": "Lunes", "titulo": "Piernas", "ejercicios": [
    {"id": "${first.id}", "series": 4, "reps": "8-10", "descanso": 90},
    {"id": "inventado", "series": 3, "reps": 12},
    {"nombre": "${first.name.toUpperCase()}", "series": 2, "segundos": 40}
  ]},
  {"dia": 3, "titulo": "Core", "ejercicios": [{"id": "${first.id}", "series": 20, "reps": "12"}]},
  {"dia": "miércoles", "titulo": "Repetido", "ejercicios": []}
], "consejos": ["Calienta 5 minutos"]}
```
Espero que te sirva.''';
      final r = parseAiPlan(text, library, newId: _id, now: DateTime(2026, 11, 10));
      expect(r.plan.name, 'Piernas fuertes');
      expect(r.plan.days.length, 7);
      final mon = r.plan.days.first;
      expect(mon.isTraining, isTrue);
      expect(mon.exercises.length, 2);
      expect(mon.exercises.first.sets, 4);
      expect(mon.exercises.first.target.min, 8);
      expect(mon.exercises.first.target.max, 10);
      expect(mon.exercises.first.restSeconds, 90);
      expect(mon.exercises[1].target.isTime, isTrue, reason: 'se reconoce por nombre');
      expect(r.plan.days[2].exercises.single.sets, 8, reason: 'series acotadas');
      expect(r.plan.days[1].isTraining, isFalse);
      expect(r.warnings.length, 2, reason: 'ejercicio inventado + día repetido');
      expect(r.tips, ['Calienta 5 minutos']);
    });

    test('errores claros', () {
      expect(() => parseAiPlan('hola', library, newId: _id), throwsA(isA<AiParseException>()));
      final prompt = buildAiPrompt(
        const AiPlanRequest(
            goal: AiGoal.salud, weekdays: {1}, minutes: 30, level: AiLevel.principiante, equipment: {}),
        library,
      );
      expect(
        () => parseAiPlan(prompt, library, newId: _id),
        throwsA(isA<AiParseException>().having((e) => e.message, 'mensaje', contains('pegaste la pregunta'))),
      );
      expect(() => parseAiPlan('{"dias": [{"dia": "lunes", "ejercicios": [{"id": "x"}]}]}', library, newId: _id),
          throwsA(isA<AiParseException>()));
    });
  });

  test('sugerencias para equilibrar', () {
    final lib = {for (final e in seedExercises) e.id: e};
    final quad = seedExercises.firstWhere((e) => e.primaryMuscle == MuscleGroup.cuadriceps);
    final now = DateTime(2026, 11, 10, 20);
    final sessions = [
      _s('1', DateTime(2026, 11, 3), quad.id, [(10, null), (10, null), (10, null), (10, null)], planned: 4),
      _s('2', DateTime(2026, 11, 6), quad.id, [(10, null), (10, null), (10, null), (10, null)], planned: 4),
      _s('3', DateTime(2026, 11, 9), quad.id, [(10, null), (10, null), (10, null), (10, null)], planned: 4),
    ];
    final m = trainingMap(sessions, (id) => lib[id], TrainingPeriod.todo, now, days: 14);
    final s = balanceSuggestions(m, seedExercises, {quad.id}, max: 9);
    final hams = s.firstWhere((x) => x.muscle == MuscleGroup.isquiotibiales);
    expect(hams.reason, contains('cuádriceps'));
    expect(hams.exercises, isNotEmpty);
    expect(hams.exercises.every((e) => e.primaryMuscle == MuscleGroup.isquiotibiales), isTrue);
    expect(s.any((x) => x.muscle == MuscleGroup.cuadriceps), isFalse);
    expect(balanceSuggestions(trainingMap(const [], (id) => null, TrainingPeriod.mes, now), seedExercises, {}), isEmpty);
  });
}

final _epoch = DateTime.utc(2026);
