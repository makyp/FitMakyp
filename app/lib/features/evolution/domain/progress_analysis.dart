/// Análisis de progreso corporal: comparativas, categorías de mejora e IMC.
/// Lógica pura (sin widgets ni almacenamiento). Todo es orientativo, no un diagnóstico.
library;

import 'dart:ui' show Color;

import '../../../core/models/body.dart';

/// Lo que la usuaria quiere en cada medida.
enum Trend {
  reduce('Reducir', '↓'),
  increase('Aumentar', '↑'),
  neutral('Solo seguir', '•');

  const Trend(this.label, this.symbol);
  final String label;
  final String symbol;
}

/// Valores por defecto (editables): cintura y abdomen a reducir, glúteos a aumentar, el resto solo se sigue.
const defaultTrends = <Measure, Trend>{
  Measure.peso: Trend.neutral,
  Measure.cintura: Trend.reduce,
  Measure.abdomen: Trend.reduce,
  Measure.cadera: Trend.neutral,
  Measure.gluteos: Trend.increase,
  Measure.musloDer: Trend.neutral,
  Measure.musloIzq: Trend.neutral,
  Measure.brazoDer: Trend.neutral,
  Measure.brazoIzq: Trend.neutral,
  Measure.pecho: Trend.neutral,
};

/// Categorías de color según el tamaño de la mejora.
enum ImprovementTier {
  gris('Sin cambio aún', 'Menos del 0,5 % o aún no va en la dirección que quieres', Color(0xFF9E9AA8)),
  amarillo('Ligera mejora', 'Entre 0,5 % y 2 %', Color(0xFFF2C14E)),
  azul('Buena mejora', 'Entre 2 % y 5 %', Color(0xFF4F8FD9)),
  morado('Gran mejora', '5 % o más', Color(0xFF7041B8)),
  seguimiento('En seguimiento', 'Medida sin objetivo: solo se muestra el cambio', Color(0xFFDCCBFA));

  const ImprovementTier(this.label, this.description, this.color);
  final String label;
  final String description;
  final Color color;
}

class MeasureComparison {
  const MeasureComparison({
    required this.measure,
    required this.from,
    required this.to,
    required this.trend,
  });

  final Measure measure;
  final double from;
  final double to;
  final Trend trend;

  double get diff => to - from;
  double get percent => from == 0 ? 0 : diff / from * 100;

  /// Porcentaje de avance en la dirección deseada (negativo = en sentido contrario).
  double get progressPercent => switch (trend) {
        Trend.reduce => -percent,
        Trend.increase => percent,
        Trend.neutral => 0,
      };

  ImprovementTier get tier {
    if (trend == Trend.neutral) return ImprovementTier.seguimiento;
    final p = progressPercent;
    if (p >= 5) return ImprovementTier.morado;
    if (p >= 2) return ImprovementTier.azul;
    if (p >= 0.5) return ImprovementTier.amarillo;
    return ImprovementTier.gris;
  }
}

/// Compara las medidas presentes en ambos registros. Las mejores mejoras van primero.
List<MeasureComparison> compareRecords(
  Map<Measure, double> from,
  Map<Measure, double> to,
  Map<Measure, Trend> trends,
) {
  final out = [
    for (final m in Measure.values)
      if (from[m] != null && to[m] != null)
        MeasureComparison(measure: m, from: from[m]!, to: to[m]!, trend: trends[m] ?? Trend.neutral),
  ];
  out.sort((a, b) {
    final ta = a.trend == Trend.neutral ? 1 : 0;
    final tb = b.trend == Trend.neutral ? 1 : 0;
    if (ta != tb) return ta - tb; // primero las que tienen objetivo
    return b.progressPercent.compareTo(a.progressPercent);
  });
  return out;
}

/// Valores "completos" de cada registro: si a un registro le falta una medida, se usa la
/// última conocida antes de él (o la primera posterior). Sirve para dibujar la silueta.
Map<Measure, double> filledValues(List<ProgressRecord> records, ProgressRecord target) {
  final sorted = [...records]..sort((a, b) => a.date.compareTo(b.date));
  final out = <Measure, double>{};
  for (final m in Measure.values) {
    double? v = target.values[m];
    if (v == null) {
      for (final r in sorted.where((r) => !r.date.isAfter(target.date))) {
        v = r.values[m] ?? v;
      }
    }
    if (v == null) {
      for (final r in sorted) {
        if (r.values[m] != null) {
          v = r.values[m];
          break;
        }
      }
    }
    if (v != null) out[m] = v;
  }
  return out;
}

/// Registro de referencia "del mes anterior": el anterior al último más cercano a 30 días antes.
ProgressRecord? monthAgoRecord(List<ProgressRecord> records) {
  if (records.length < 2) return null;
  final sorted = [...records]..sort((a, b) => a.date.compareTo(b.date));
  final latest = sorted.last;
  final target = latest.date.subtract(const Duration(days: 30));
  ProgressRecord? best;
  for (final r in sorted.sublist(0, sorted.length - 1)) {
    if (best == null || (r.date.difference(target).abs() < best.date.difference(target).abs())) best = r;
  }
  return best;
}

// ---------------------------------------------------------------- IMC

enum BmiCategory {
  bajo('Bajo peso', 0, 18.5, Color(0xFF4F8FD9)),
  normal('Rango saludable', 18.5, 25, Color(0xFF7CCFC3)),
  sobrepeso('Sobrepeso', 25, 30, Color(0xFFF2C14E)),
  obesidad('Obesidad', 30, 99, Color(0xFFF2A07A));

  const BmiCategory(this.label, this.min, this.max, this.color);
  final String label;
  final double min;
  final double max;
  final Color color;
}

/// IMC = kg / m².
double bmi(double weightKg, double heightCm) {
  final m = heightCm / 100;
  return weightKg / (m * m);
}

BmiCategory bmiCategory(double value) =>
    BmiCategory.values.firstWhere((c) => value < c.max, orElse: () => BmiCategory.obesidad);

/// Rango de peso que corresponde al IMC 18,5-24,9 para una estatura (referencia OMS para adultos).
(double, double) healthyWeightRange(double heightCm) {
  final m = heightCm / 100;
  return (18.5 * m * m, 24.9 * m * m);
}
