import 'dart:io';

import 'package:fitmakyp/core/data/seed_exercises.dart';
import 'package:fitmakyp/core/models/exercise.dart';
import 'package:fitmakyp/shared/widgets/body_figure.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cada ejercicio de la biblioteca tiene sus imágenes y un id único', () {
    final ids = <String>{};
    for (final e in seedExercises) {
      expect(ids.add(e.id), isTrue, reason: 'id repetido: ${e.id}');
      for (final src in [e.media.src, e.media.endSrc]) {
        expect(src, isNotNull, reason: e.id);
        if (e.media.kind == MediaKind.figure) {
          expect(figurePoseOf(src), isNotNull, reason: 'postura desconocida: $src');
        } else {
          expect(File(src!).existsSync(), isTrue, reason: 'falta $src');
        }
      }
      expect(e.instructions, isNotEmpty, reason: e.id);
    }
    expect(seedExercises.length, greaterThanOrEqualTo(67));
    expect(seedExercises.where((e) => e.id.startsWith('boxeo_')), hasLength(8));
  });
}
