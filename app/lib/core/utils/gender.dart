import 'package:flutter/widgets.dart';

import '../../app_scope.dart';
import '../models/exercise.dart';

/// Textos personalizados según el sexo elegido en Perfil.
/// La app está escrita en femenino; si la persona es hombre, se pasan a masculino
/// las palabras que se refieren a ella (no las que concuerdan con otra cosa,
/// como "la espalda apoyada"). Con "prefiero no decir" se deja como está.
const _toMasculine = {
  'Tumbada': 'Tumbado',
  'tumbada': 'tumbado',
  'Sentada': 'Sentado',
  'sentada': 'sentado',
  'Inclinada': 'Inclinado',
  'estés cómoda': 'estés cómodo',
  '¿Lista?': '¿Listo?',
  'Hidratada': 'Hidratado',
  'campeona': 'campeón',
  'Campeona': 'Campeón',
  'heroína': 'héroe',
  'Heroína': 'Héroe',
};

final _patterns = {
  for (final e in _toMasculine.entries)
    // Sin letras pegadas a cada lado (para no tocar trozos de otras palabras).
    RegExp('(?<![\\p{L}])${RegExp.escape(e.key)}(?![\\p{L}])', unicode: true): e.value,
};

String genderize(String text, String sex) {
  if (sex != 'hombre' || text.isEmpty) return text;
  var out = text;
  for (final e in _patterns.entries) {
    out = out.replaceAll(e.key, e.value);
  }
  return out;
}

/// El ejercicio con sus textos personalizados (solo para mostrar; al editar se usa el original).
Exercise genderExercise(Exercise e, String sex) => sex != 'hombre'
    ? e
    : e.copyWith(
        description: genderize(e.description, sex),
        instructions: [for (final s in e.instructions) genderize(s, sex)],
        commonMistakes: [for (final s in e.commonMistakes) genderize(s, sex)],
        startPosition: genderize(e.startPosition, sex),
        endPosition: genderize(e.endPosition, sex),
      );

extension GenderText on BuildContext {
  String get sex => AppScope.of(this).settings.settings.sex;
  bool get isMan => sex == 'hombre';

  /// Texto personalizado según el sexo.
  String g(String text) => genderize(text, sex);
}
