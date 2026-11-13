/// "Método de la mano": registrar comidas sin pesar ni medir.
/// Tu mano es tu medida y crece contigo. Estimaciones orientativas, no una pauta médica.
library;

enum HandPortion {
  proteina(
    'Proteína',
    '✋',
    'palma',
    'palmas',
    'Del tamaño y grosor de tu palma: pollo, carne, pescado, huevos (2), tofu, legumbres.',
    protein: 22,
    kcal: 110,
  ),
  carbos(
    'Carbohidratos',
    '🤲',
    'mano ahuecada',
    'manos ahuecadas',
    'Lo que cabe en tu mano ahuecada: arroz, pasta, papa, avena, pan (1 rebanada), fruta.',
    protein: 3,
    kcal: 110,
  ),
  verduras(
    'Verduras',
    '✊',
    'puño',
    'puños',
    'Del tamaño de tu puño: ensalada, brócoli, zanahoria, tomate, espinaca…',
    protein: 1,
    kcal: 25,
  ),
  grasas(
    'Grasas',
    '👍',
    'pulgar',
    'pulgares',
    'Del tamaño de tu pulgar: aceite, mantequilla, aguacate, frutos secos, queso.',
    protein: 1,
    kcal: 50,
  );

  const HandPortion(this.label, this.emoji, this.unit, this.unitPlural, this.hint,
      {required this.protein, required this.kcal});
  final String label;
  final String emoji;
  final String unit;
  final String unitPlural;
  final String hint;

  /// Aproximado por porción.
  final int protein;
  final int kcal;
}

/// Porciones de una comida (admite medias: 0,5).
class HandPortions {
  const HandPortions([this.values = const {}]);
  final Map<HandPortion, double> values;

  double operator [](HandPortion p) => values[p] ?? 0;

  bool get isEmpty => values.values.every((v) => v <= 0);

  HandPortions withValue(HandPortion p, double v) =>
      HandPortions({...values, p: v.clamp(0, 10).toDouble()});

  HandPortions operator +(HandPortions o) =>
      HandPortions({for (final p in HandPortion.values) p: this[p] + o[p]});

  int get protein => HandPortion.values.fold(0.0, (a, p) => a + this[p] * p.protein).round();
  int get kcal => HandPortion.values.fold(0.0, (a, p) => a + this[p] * p.kcal).round();

  Map<String, double> toJson() => {
        for (final e in values.entries)
          if (e.value > 0) e.key.name: e.value,
      };

  static HandPortions? fromJson(Object? j) {
    if (j is! Map) return null;
    final m = <HandPortion, double>{
      for (final e in j.entries)
        if (HandPortion.values.asNameMap()[e.key] case final p?)
          if (e.value is num) p: (e.value as num).toDouble(),
    };
    final h = HandPortions(m);
    return h.isEmpty ? null : h;
  }

  /// "1½", "2", "½".
  static String amount(double v) {
    final whole = v.floor();
    final half = v - whole >= 0.5;
    if (whole == 0) return half ? '½' : '0';
    return half ? '$whole½' : '$whole';
  }

  /// "✋1 🤲½ ✊2"
  String get short => [
        for (final p in HandPortion.values)
          if (this[p] > 0) '${p.emoji}${amount(this[p])}',
      ].join('  ');
}
