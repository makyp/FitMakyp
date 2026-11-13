/// Descanso estimado a partir del uso del teléfono: el tramo más largo de la noche
/// sin usarlo (de 2 h o más) y la "primera activación" de la mañana.
/// Es una estimación orientativa: no mide el sueño de verdad ni es un diagnóstico.
library;

import 'dart:math' as math;

class NightRest {
  const NightRest({required this.morning, required this.lastUse, required this.firstUse});

  /// Día de la mañana en que terminó la noche.
  final DateTime morning;

  /// Último uso antes de desconectar.
  final DateTime lastUse;

  /// Primera activación de la mañana.
  final DateTime firstUse;

  Duration get offPhone => firstUse.difference(lastUse);

  RestLevel get level => restLevelFor(offPhone);
}

enum RestLevel {
  bueno('Buen descanso', '😴'),
  justo('Un poco corto', '🙂'),
  corto('Noche corta', '🥱');

  const RestLevel(this.label, this.emoji);
  final String label;
  final String emoji;
}

RestLevel restLevelFor(Duration d) => d.inMinutes >= 7 * 60
    ? RestLevel.bueno
    : d.inMinutes >= 6 * 60
        ? RestLevel.justo
        : RestLevel.corto;

/// Desde las 18:00 del día anterior hasta las 14:00 de [morning].
(DateTime, DateTime) nightWindow(DateTime morning) {
  final d = DateTime(morning.year, morning.month, morning.day);
  return (d.subtract(const Duration(hours: 6)), d.add(const Duration(hours: 14)));
}

/// Noches de las últimas [nights] mañanas (la más reciente primero).
/// [uses] son momentos en que se usó el teléfono (desbloqueos o apps abiertas).
List<NightRest> estimateNights(
  List<DateTime> uses, {
  required DateTime now,
  int nights = 7,
  Duration minGap = const Duration(hours: 2),
}) {
  final sorted = [...uses]..sort();
  final out = <NightRest>[];
  for (var i = 0; i < nights; i++) {
    final morning = DateTime(now.year, now.month, now.day - i);
    final (from, to) = nightWindow(morning);
    final inside = sorted.where((u) => !u.isBefore(from) && u.isBefore(to)).toList();
    Duration best = Duration.zero;
    NightRest? rest;
    for (var k = 1; k < inside.length; k++) {
      final gap = inside[k].difference(inside[k - 1]);
      if (gap > best) {
        best = gap;
        rest = NightRest(morning: morning, lastUse: inside[k - 1], firstUse: inside[k]);
      }
    }
    if (rest != null && best >= minGap) out.add(rest);
  }
  return out;
}

/// Resumen de varias noches.
class RestSummary {
  RestSummary(this.nights);
  final List<NightRest> nights;

  bool get isEmpty => nights.isEmpty;

  Duration get average => nights.isEmpty
      ? Duration.zero
      : Duration(minutes: nights.fold<int>(0, (a, n) => a + n.offPhone.inMinutes) ~/ nights.length);

  static int _minuteOfDay(DateTime d) => d.hour * 60 + d.minute;

  /// Hora media de la primera activación (minutos desde medianoche).
  int? get averageWake =>
      nights.isEmpty ? null : nights.fold<int>(0, (a, n) => a + _minuteOfDay(n.firstUse)) ~/ nights.length;

  /// Hora media del último uso (se cuenta pasada la medianoche como 24 h +).
  int? get averageLastUse {
    if (nights.isEmpty) return null;
    final v = nights.fold<int>(0, (a, n) {
      final m = _minuteOfDay(n.lastUse);
      return a + (m < 12 * 60 ? m + 24 * 60 : m);
    });
    return (v ~/ nights.length) % (24 * 60);
  }

  /// Diferencia típica (minutos) en la hora de levantarse: menos es más regular.
  int? get wakeSpread {
    if (nights.length < 2) return null;
    final m = nights.map((n) => _minuteOfDay(n.firstUse)).toList();
    final mean = m.reduce((a, b) => a + b) / m.length;
    final variance = m.fold<double>(0, (a, x) => a + (x - mean) * (x - mean)) / m.length;
    return math.sqrt(variance).round();
  }
}

String formatHm(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes % 60;
  return m == 0 ? '$h h' : '$h h $m min';
}

String formatClockMinutes(int minutes) =>
    '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';

String formatTime(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
