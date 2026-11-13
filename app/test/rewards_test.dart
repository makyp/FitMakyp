import 'dart:typed_data';

import 'package:fitmakyp/core/models/body.dart';
import 'package:fitmakyp/core/models/exercise.dart';
import 'package:fitmakyp/core/models/goal.dart';
import 'package:fitmakyp/core/models/session.dart';
import 'package:fitmakyp/core/storage/local_store.dart';
import 'package:fitmakyp/features/evolution/state/body_repository.dart';
import 'package:fitmakyp/features/goals/domain/rewards.dart';
import 'package:fitmakyp/features/pet/domain/pet_items.dart';
import 'package:fitmakyp/features/pet/state/pet_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes.dart';

WorkoutSession _session(String id, DateTime day, {int done = 3, int planned = 3}) => WorkoutSession(
      id: id,
      planId: 'p',
      dayId: 'd',
      dayTitle: 't',
      status: SessionStatus.completed,
      startedAt: day,
      exercises: [
        SessionExercise(
          workoutExerciseId: 'w',
          exerciseId: 'e',
          name: 'e',
          plannedSets: planned,
          target: const SetTarget.reps(10),
          restSeconds: 60,
          sets: [
            for (var i = 0; i < done; i++)
              ExerciseSetLog(setNumber: i + 1, result: SetResult.completed, finishedAt: day),
          ],
        ),
      ],
    );

RewardsInput _input({
  List<WorkoutSession> sessions = const [],
  List<ProgressRecord> records = const [],
  List<Goal> goals = const [],
  int streak = 0,
  int best = 0,
}) =>
    RewardsInput(
      sessions: sessions,
      records: records,
      checkins: const [],
      goals: goals,
      currentStreak: streak,
      bestStreak: best,
      now: DateTime(2026, 11, 20),
    );

void main() {
  test('puntos: entrenamiento completo, parcial, registros semanales y rachas', () {
    final pts = totalEarned(_input(
      sessions: [
        _session('a', DateTime(2026, 11, 2)), // completo: 20 + 10
        _session('b', DateTime(2026, 11, 3), done: 1), // parcial: 20
        _session('c', DateTime(2026, 11, 4), done: 0), // nada
      ],
      records: [
        ProgressRecord(id: 'r1', date: DateTime(2026, 11, 2)),
        ProgressRecord(id: 'r2', date: DateTime(2026, 11, 4)), // misma semana: no suma
        ProgressRecord(id: 'r3', date: DateTime(2026, 11, 10)),
      ],
      best: 7, // 30 + 70
    ));
    // + insignias: Primer paso (20), Madrugadora (30: las sesiones son a las 00:00) y Punto de partida (20).
    expect(pts, 30 + 20 + 25 * 2 + 30 + 70 + 20 + 30 + 20);
  });

  test('niveles', () {
    expect(levelFor(0), 1);
    expect(levelFor(99), 1);
    expect(levelFor(100), 2);
    expect(levelFor(700), 5);
    expect(levelProgress(175), closeTo(0.5, 0.001));
  });

  test('meta de peso funciona tanto para bajar como para subir', () {
    final bajar = Goal(id: 'g', type: GoalType.weight, target: 60, startValue: 64, createdAt: DateTime(2026));
    expect(goalProgress(bajar, _input(), latestValue: 62).fraction, closeTo(0.5, 0.001));
    expect(goalProgress(bajar, _input(), latestValue: 59.5).reached, isTrue);
    expect(goalProgress(bajar, _input(), latestValue: 66).fraction, 0);

    final subir = Goal(id: 'h', type: GoalType.weight, target: 55, startValue: 50, createdAt: DateTime(2026));
    expect(goalProgress(subir, _input(), latestValue: 52.5).fraction, closeTo(0.5, 0.001));
  });

  test('meta de días seguidos usa la racha actual', () {
    final g = Goal(id: 'g', type: GoalType.streak, target: 7, createdAt: DateTime(2026));
    expect(goalProgress(g, _input(streak: 7)).reached, isTrue);
    expect(goalProgress(g, _input(streak: 3)).fraction, closeTo(3 / 7, 0.001));
  });

  test('aviso de meta de peso extrema', () {
    expect(weightGoalWarning(current: 70, target: 66), isNull);
    expect(weightGoalWarning(current: 70, target: 55), isNotNull);
  });

  test('cambio de medida: diferencia y porcentaje válido', () {
    const d = MeasureDelta(80, 76);
    expect(d.diff, -4);
    expect(d.percent, closeTo(-5, 0.001));
    expect(const MeasureDelta(0, 5).percent, isNull);
  });

  test('tienda: no se puede comprar sin puntos ni nivel', () async {
    SharedPreferences.setMockInitialValues({});
    final pet = PetRepository(await LocalStore.open());
    final corona = petItemById('corona')!;
    expect(await pet.buy(corona, balance: 1000, level: 1), contains('nivel'));
    final lazo = petItemById('lazo')!;
    expect(await pet.buy(lazo, balance: 10, level: 1), contains('faltan'));
    expect(await pet.buy(lazo, balance: 100, level: 1), isNull);
    expect(pet.spent, lazo.price);
    expect(pet.look.head, 'lazo');
  });

  test('registros corporales: guardar, series, borrar fotos y copia de seguridad', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await LocalStore.open();
    final photos = MemoryPhotoStore();
    final body = BodyRepository(store, photos);
    final photo = await body.savePhoto(Uint8List.fromList([1, 2, 3]));
    await body.saveRecord(date: DateTime(2026, 11, 1), values: {Measure.peso: 64}, photoIds: {PhotoAngle.frontal: photo});
    final r2 = await body.saveRecord(date: DateTime(2026, 11, 15), values: {Measure.peso: 63, Measure.cintura: 74}, photoIds: {});
    expect(body.series(Measure.peso).map((p) => p.$2), [64, 63]);
    expect(body.totalChange(Measure.peso)!.diff, -1);
    expect(body.nextEvaluation, DateTime(2026, 11, 30));

    // Copia de seguridad de los datos y restauración en un "teléfono nuevo".
    final exported = store.exportAll();
    SharedPreferences.setMockInitialValues({});
    final store2 = await LocalStore.open();
    await store2.replaceAll(exported);
    final body2 = BodyRepository(store2, photos);
    expect(body2.records.length, 2);
    expect(body2.latestValue(Measure.cintura), 74);

    await body.deleteRecord(body.records.first.id);
    expect(await photos.load(photo), isNull, reason: 'al borrar el registro se borra su foto');
    expect(body.byId(r2.id), isNotNull);
  });
}
