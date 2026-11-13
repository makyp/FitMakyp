import '../../core/storage/local_store.dart';
import 'domain/cycle.dart';

/// Guarda el ciclo en el teléfono (entra en la copia de seguridad, nunca en el reporte ni en la IA).
class CycleStore {
  CycleStore(this._store) {
    final raw = _store.readJson(_key);
    if (raw is Map) {
      _periods = [
        for (final p in (raw['periods'] as List?) ?? const []) ?Period.fromJson(p),
      ]..sort((a, b) => a.start.compareTo(b.start));
      final days = raw['days'];
      if (days is Map) {
        _days = {for (final e in days.entries) '${e.key}': CycleDay.fromJson(e.value)};
      }
    }
  }

  static const _key = 'cycle';

  /// Se llama cada vez que cambia el ciclo (para reprogramar el aviso).
  static void Function()? onChanged;
  final LocalStore _store;
  List<Period> _periods = [];
  Map<String, CycleDay> _days = {};

  static String key(DateTime d) => DateTime(d.year, d.month, d.day).toIso8601String().substring(0, 10);
  static DateTime _date(DateTime d) => DateTime(d.year, d.month, d.day);

  List<Period> get periods => List.unmodifiable(_periods);
  CycleStatus get status => CycleStatus.from(_periods);
  CycleDay dayOn(DateTime d) => _days[key(d)] ?? const CycleDay();

  /// Días con síntomas anotados.
  Map<DateTime, CycleDay> get notedDays => {
        for (final e in _days.entries) ?DateTime.tryParse(e.key): e.value,
      };

  Future<void> setDay(DateTime d, CycleDay day) {
    if (day.isEmpty) {
      _days.remove(key(d));
    } else {
      _days[key(d)] = day;
    }
    return _save();
  }

  /// "Me bajó" en [day]. Cierra la regla anterior si quedó abierta.
  Future<void> startPeriod(DateTime day) async {
    final d = _date(day);
    final st = status;
    if (st.periodOn(d) != null) return; // ya estaba registrada
    _periods = [
      for (final p in _periods)
        if (p.end == null && p.start.isBefore(d))
          Period(p.start, _minDate(DateTime(p.start.year, p.start.month, p.start.day + st.avgPeriod - 1), DateTime(d.year, d.month, d.day - 1)))
        else
          p,
      Period(d),
    ]..sort((a, b) => a.start.compareTo(b.start));
    final cur = dayOn(d);
    if (cur.flow == 0) _days[key(d)] = CycleDay(flow: 2, symptoms: cur.symptoms);
    await _save();
  }

  /// "Terminó" en [day] (último día con regla).
  Future<void> endPeriod(DateTime day) async {
    final d = _date(day);
    final p = status.periodOn(d);
    if (p == null) return;
    _periods = [for (final x in _periods) identical(x, p) || x.start == p.start ? Period(x.start, d) : x];
    await _save();
  }

  Future<void> deletePeriod(Period p) async {
    _periods.removeWhere((x) => x.start == p.start);
    await _save();
  }

  static DateTime _minDate(DateTime a, DateTime b) => a.isBefore(b) ? a : b;

  Future<void> _save() async {
    await _store.writeJson(_key, {
      'periods': [for (final p in _periods) p.toJson()],
      'days': {for (final e in _days.entries) e.key: e.value.toJson()},
    });
    onChanged?.call();
  }
}
