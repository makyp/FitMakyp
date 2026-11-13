import 'dart:io';

import 'package:fitmakyp/core/data/seed_exercises.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cada ejercicio de la biblioteca tiene sus imágenes y un id único', () {
    final ids = <String>{};
    for (final e in seedExercises) {
      expect(ids.add(e.id), isTrue, reason: 'id repetido: ${e.id}');
      for (final src in [e.media.src, e.media.endSrc]) {
        expect(src, isNotNull, reason: e.id);
        expect(File(src!).existsSync(), isTrue, reason: 'falta $src');
      }
      expect(e.instructions, isNotEmpty, reason: e.id);
    }
    expect(seedExercises.length, greaterThanOrEqualTo(59));
  });
}
