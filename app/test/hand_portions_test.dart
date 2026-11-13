import 'dart:io';

import 'package:fitmakyp/core/models/habits.dart';
import 'package:fitmakyp/features/habits/domain/hand_portions.dart';
import 'package:fitmakyp/features/workout/domain/warmup.dart';
import 'package:fitmakyp/core/models/exercise.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('porciones con la mano estiman proteína y calorías', () {
    final p = const HandPortions()
        .withValue(HandPortion.proteina, 1)
        .withValue(HandPortion.carbos, 1)
        .withValue(HandPortion.verduras, 2)
        .withValue(HandPortion.grasas, 0.5);
    expect(p.protein, 28); // 22 + 3 + 2 + 0,5 = 27,5
    expect(p.kcal, 110 + 110 + 50 + 25);
    expect(p.short, '✋1  🤲1  ✊2  👍½');
    expect(HandPortions.amount(1.5), '1½');
  });

  test('la comida guarda y recupera las porciones', () {
    final m = MealEntry(
      id: 'm1',
      at: DateTime(2026, 11, 11, 13),
      type: MealType.almuerzo,
      description: 'Arroz con pollo',
      kcal: 220,
      protein: 25,
      portions: const HandPortions({HandPortion.proteina: 1, HandPortion.carbos: 1}),
    );
    final back = MealEntry.fromJson(m.toJson());
    expect(back.portions![HandPortion.proteina], 1);
    expect(back.portions![HandPortion.carbos], 1);
    expect(MealEntry.fromJson({...m.toJson()}..remove('portions')).portions, isNull);
  });

  test('todos los movimientos con foto tienen sus dos imágenes', () {
    final moves = {
      ...warmupFor(MuscleGroup.values),
      ...cooldownFor(MuscleGroup.values),
      ...warmupFor(const [MuscleGroup.abdomen]),
      ...cooldownFor(const [MuscleGroup.gluteos]),
      ...cooldownFor(const [MuscleGroup.gemelos]),
    };
    for (final m in moves.where((m) => m.hasPhoto)) {
      expect(File(m.photoStart).existsSync(), isTrue, reason: m.photoStart);
      expect(File(m.photoEnd).existsSync(), isTrue, reason: m.photoEnd);
    }
  });
}
