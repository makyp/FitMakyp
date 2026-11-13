/// Seguimiento del ciclo menstrual. Lógica pura.
/// Todo es orientativo: las fechas son estimaciones y no sirven como método anticonceptivo.
library;

import 'dart:ui' show Color;

DateTime _d(DateTime x) => DateTime(x.year, x.month, x.day);
DateTime _plus(DateTime x, int days) => DateTime(x.year, x.month, x.day + days);
/// Días de calendario entre dos fechas (sin líos de cambio de hora).
int _days(DateTime a, DateTime b) =>
    DateTime.utc(b.year, b.month, b.day).difference(DateTime.utc(a.year, a.month, a.day)).inDays;

class Period {
  const Period(this.start, [this.end]);
  final DateTime start;

  /// Último día con regla (null = sigue en curso).
  final DateTime? end;

  int? get length => end == null ? null : _days(start, end!) + 1;

  Map<String, dynamic> toJson() => {
        'start': _d(start).toIso8601String().substring(0, 10),
        if (end != null) 'end': _d(end!).toIso8601String().substring(0, 10),
      };

  static Period? fromJson(Object? j) {
    if (j is! Map) return null;
    final s = DateTime.tryParse('${j['start']}');
    if (s == null) return null;
    return Period(s, j['end'] == null ? null : DateTime.tryParse('${j['end']}'));
  }
}

enum Symptom {
  colicos('Cólicos', '🌀'),
  hinchazon('Hinchazón', '🎈'),
  cabeza('Dolor de cabeza', '🤕'),
  cansancio('Cansancio', '🥱'),
  antojos('Antojos', '🍫'),
  pecho('Pecho sensible', '💗'),
  granitos('Granitos', '✨'),
  animo('Cambios de ánimo', '🎭'),
  lumbar('Dolor lumbar', '🔙');

  const Symptom(this.label, this.emoji);
  final String label;
  final String emoji;
}

/// Lo anotado en un día: flujo (0 = nada, 1 ligero, 2 medio, 3 abundante) y síntomas.
class CycleDay {
  const CycleDay({this.flow = 0, this.symptoms = const {}});
  final int flow;
  final Set<Symptom> symptoms;

  bool get isEmpty => flow == 0 && symptoms.isEmpty;

  Map<String, dynamic> toJson() => {'flow': flow, 'symptoms': [for (final s in symptoms) s.name]};

  static CycleDay fromJson(Object? j) {
    if (j is! Map) return const CycleDay();
    return CycleDay(
      flow: (j['flow'] as num?)?.toInt() ?? 0,
      symptoms: {
        for (final s in (j['symptoms'] as List?) ?? const []) ?Symptom.values.asNameMap()[s],
      },
    );
  }
}

const flowLabels = ['Nada', 'Ligero', 'Medio', 'Abundante'];

enum CyclePhase {
  menstrual(
    'Menstruación',
    '🩸',
    Color(0xFFE5737A),
    'Muévete según cómo te sientas: caminar, movilidad o fuerza más suave están bien. Si te encuentras con energía, entrena normal.',
  ),
  folicular(
    'Fase folicular',
    '🌱',
    Color(0xFF3FBF9F),
    'Muchas personas notan más energía: buen momento para retos y para subir un poco los pesos si te sientes bien.',
  ),
  ovulatoria(
    'Ovulación (aprox.)',
    '🌸',
    Color(0xFFF2A5C6),
    'Suele ser un pico de energía. Calienta bien y cuida la técnica en los ejercicios de salto o cambios de dirección.',
  ),
  lutea(
    'Fase lútea',
    '🌙',
    Color(0xFF9468E0),
    'Puede costar un poco más y tener más hambre o hinchazón. Prioriza descanso, agua y no te exijas récords si no te salen.',
  );

  const CyclePhase(this.label, this.emoji, this.color, this.tip);
  final String label;
  final String emoji;
  final Color color;
  final String tip;
}

/// Medias y predicción a partir de las reglas registradas.
class CycleStatus {
  CycleStatus._(this.periods, this.avgCycle, this.avgPeriod, this.cycleCount);

  factory CycleStatus.from(List<Period> periods) {
    final p = [...periods]..sort((a, b) => a.start.compareTo(b.start));
    final cycles = <int>[
      for (var i = 1; i < p.length; i++) _days(p[i - 1].start, p[i].start),
    ].where((c) => c >= 15 && c <= 60).toList();
    final recent = cycles.length > 6 ? cycles.sublist(cycles.length - 6) : cycles;
    final lens = [for (final x in p) x.length].whereType<int>().where((l) => l >= 1 && l <= 10).toList();
    final recentLens = lens.length > 6 ? lens.sublist(lens.length - 6) : lens;
    return CycleStatus._(
      p,
      recent.isEmpty ? 28 : (recent.reduce((a, b) => a + b) / recent.length).round(),
      recentLens.isEmpty ? 5 : (recentLens.reduce((a, b) => a + b) / recentLens.length).round(),
      cycles.length,
    );
  }

  /// Ordenadas de la más antigua a la más reciente.
  final List<Period> periods;
  final int avgCycle;
  final int avgPeriod;

  /// Ciclos completos usados para las medias (con 0 se usan 28 y 5 días por defecto).
  final int cycleCount;

  bool get hasData => periods.isNotEmpty;

  Period? get last => periods.isEmpty ? null : periods.last;

  /// Regla en curso hoy.
  bool inPeriodOn(DateTime day) {
    final l = periodOn(day);
    return l != null;
  }

  /// Regla registrada que incluye [day] (si la última no tiene fin, se cuentan hasta 10 días).
  Period? periodOn(DateTime day) {
    for (final p in periods.reversed) {
      if (_d(day).isBefore(_d(p.start))) continue;
      final end = p.end ?? _plus(p.start, 9);
      if (!_d(day).isAfter(_d(end))) return p;
      return null;
    }
    return null;
  }

  /// Día del ciclo (1 = primer día de regla) para [day], o null sin datos.
  int? cycleDay(DateTime day) {
    Period? start;
    for (final p in periods.reversed) {
      if (!_d(p.start).isAfter(_d(day))) {
        start = p;
        break;
      }
    }
    if (start == null) return null;
    return _days(start.start, day) + 1;
  }

  DateTime? get nextStart => last == null ? null : _plus(last!.start, avgCycle);

  /// Días que faltan para la próxima regla (negativo = retraso).
  int? daysUntilNext(DateTime now) => nextStart == null ? null : _days(now, nextStart!);

  DateTime? get ovulation => nextStart == null ? null : _plus(nextStart!, -14);

  /// Fase estimada en [day].
  CyclePhase? phaseOn(DateTime day) {
    final n = cycleDay(day);
    if (n == null) return null;
    final p = periodOn(day);
    if (p != null) return CyclePhase.menstrual;
    // Para días pasados se usa el ciclo real (hasta la siguiente regla registrada).
    var length = avgCycle;
    for (var i = 0; i < periods.length - 1; i++) {
      final a = periods[i].start, b = periods[i + 1].start;
      if (!_d(day).isBefore(_d(a)) && _d(day).isBefore(_d(b))) length = _days(a, b);
    }
    final ov = length - 14;
    if (n <= avgPeriod) return CyclePhase.menstrual;
    if (n >= ov - 2 && n <= ov + 1) return CyclePhase.ovulatoria;
    if (n < ov - 2) return CyclePhase.folicular;
    return CyclePhase.lutea;
  }

  /// ¿Día estimado de regla (futuro)?
  bool predictedPeriodOn(DateTime day) {
    final n = nextStart;
    if (n == null || !_d(day).isAfter(_d(DateTime.now()))) return false;
    for (var k = 0; k < 3; k++) {
      final s = _plus(n, avgCycle * k);
      final diff = _days(s, day);
      if (diff >= 0 && diff < avgPeriod) return true;
    }
    return false;
  }
}

/// Media de un valor (1-5) por fase. Solo fases con al menos [min] registros.
Map<CyclePhase, double> averageByPhase(
  CycleStatus status,
  Iterable<(DateTime, int)> values, {
  int min = 2,
}) {
  final sums = <CyclePhase, (int, int)>{};
  for (final (day, v) in values) {
    final ph = status.phaseOn(day);
    if (ph == null) continue;
    final (s, c) = sums[ph] ?? (0, 0);
    sums[ph] = (s + v, c + 1);
  }
  return {
    for (final e in sums.entries)
      if (e.value.$2 >= min) e.key: e.value.$1 / e.value.$2,
  };
}
