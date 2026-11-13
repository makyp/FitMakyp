import '../../core/storage/local_store.dart';
import 'domain/hypopressive.dart';

/// Días en que se hizo la rutina matutina y nivel elegido.
class MorningLog {
  static const _doneKey = 'morningDone';
  static const _levelKey = 'morningLevel';

  static String _day(DateTime d) => d.toIso8601String().substring(0, 10);

  static Set<String> _done(LocalStore s) =>
      {for (final x in (s.readJson(_doneKey) as List?) ?? const []) x.toString()};

  static bool doneOn(LocalStore s, DateTime d) => _done(s).contains(_day(d));
  static int total(LocalStore s) => _done(s).length;

  static Future<void> markDone(LocalStore s, DateTime d) =>
      s.writeJson(_doneKey, ({..._done(s), _day(d)}.toList()..sort()));

  /// Mañanas hechas entre [from] y [to] (incluidos).
  static int countBetween(LocalStore s, DateTime from, DateTime to) =>
      _done(s).where((d) => d.compareTo(_day(from)) >= 0 && d.compareTo(_day(to)) <= 0).length;

  static HypoLevel level(LocalStore s) =>
      HypoLevel.values.asNameMap()[s.readJson(_levelKey)] ?? HypoLevel.suave;
  static Future<void> setLevel(LocalStore s, HypoLevel l) => s.writeJson(_levelKey, l.name);

  /// Días hechos (para puntos y retos).
  static Set<DateTime> days(LocalStore s) => {for (final d in _done(s)) ?DateTime.tryParse(d)};
}
