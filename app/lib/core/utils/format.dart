const _months = ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'];
const _weekdays = ['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'];

/// "02:00"
String formatClock(Duration d) {
  final total = d.inSeconds < 0 ? 0 : (d.inMilliseconds / 1000).ceil();
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  final s = total % 60;
  final mm = m.toString().padLeft(2, '0');
  final ss = s.toString().padLeft(2, '0');
  return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
}

/// "45 min" / "1 h 05 min"
String formatDurationShort(Duration d) {
  final m = d.inMinutes;
  if (m < 60) return '$m min';
  return '${m ~/ 60} h ${(m % 60).toString().padLeft(2, '0')} min';
}

/// "lunes, 9 de noviembre"
String formatLongDate(DateTime d) => '${_weekdays[d.weekday - 1]}, ${d.day} de ${_months[d.month - 1]}';

String formatShortDate(DateTime d) => '${d.day} ${_months[d.month - 1].substring(0, 3)}';

/// Fecha sin hora (para comparar días).
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

String greeting(DateTime now) {
  if (now.hour < 12) return 'Buenos días';
  if (now.hour < 19) return 'Buenas tardes';
  return 'Buenas noches';
}
