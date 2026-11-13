import 'package:fitmakyp/core/data/seed_exercises.dart';
import 'package:fitmakyp/core/utils/gender.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('para hombres pasa a masculino lo que se refiere a la persona', () {
    expect(genderize('Tumbada boca arriba, con la espalda apoyada.', 'hombre'), 'Tumbado boca arriba, con la espalda apoyada.');
    expect(genderize('¿Lista? Este es tu entrenamiento de hoy', 'hombre'), '¿Listo? Este es tu entrenamiento de hoy');
    expect(genderize('Capa de heroína', 'hombre'), 'Capa de héroe');
    expect(genderize('Banda de campeona', 'hombre'), 'Banda de campeón');
  });

  test('para mujer o "prefiero no decir" no cambia nada', () {
    expect(genderize('Tumbada boca arriba', 'mujer'), 'Tumbada boca arriba');
    expect(genderize('Tumbada boca arriba', 'no_decir'), 'Tumbada boca arriba');
  });

  test('ningún ejercicio queda en femenino para hombres', () {
    final bad = RegExp(r'\b(tumbada|sentada)\b', caseSensitive: false);
    for (final e in seedExercises) {
      final g = genderExercise(e, 'hombre');
      for (final s in [g.description, g.startPosition, g.endPosition, ...g.instructions, ...g.commonMistakes]) {
        expect(bad.hasMatch(s), isFalse, reason: '${e.id}: $s');
      }
    }
  });
}
