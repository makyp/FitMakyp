import 'package:flutter/foundation.dart';

import '../../../core/models/body.dart';
import '../../../core/storage/local_store.dart';
import '../../../core/storage/photo_store.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/ids.dart';
import '../domain/progress_analysis.dart';

/// Peso, medidas, fotos y registro diario.
class BodyRepository extends ChangeNotifier {
  BodyRepository(this._store, this.photos) {
    final raw = _store.readJson(_recordsKey);
    if (raw is List) {
      _records = [for (final r in raw) ProgressRecord.fromJson(r as Map<String, dynamic>)];
    }
    final rawC = _store.readJson(_checkinsKey);
    if (rawC is List) {
      _checkins = [for (final c in rawC) DailyCheckin.fromJson(c as Map<String, dynamic>)];
    }
    final every = _store.readJson(_everyKey);
    if (every is int) _evaluationEveryDays = every;
    final height = _store.readJson(_heightKey);
    if (height is num) _heightCm = height.toDouble();
    final trends = _store.readJson(_trendsKey);
    if (trends is Map<String, dynamic>) {
      for (final e in trends.entries) {
        if (Measure.values.any((m) => m.name == e.key) && Trend.values.any((t) => t.name == e.value)) {
          _trends[Measure.values.byName(e.key)] = Trend.values.byName(e.value as String);
        }
      }
    }
  }

  static const _recordsKey = 'progressRecords';
  static const _checkinsKey = 'checkins';
  static const _everyKey = 'evaluationEveryDays';
  static const _heightKey = 'heightCm';
  static const _trendsKey = 'measureTrends';

  final LocalStore _store;
  final PhotoStore photos;
  List<ProgressRecord> _records = [];
  List<DailyCheckin> _checkins = [];
  int _evaluationEveryDays = 15;
  double? _heightCm;
  final Map<Measure, Trend> _trends = Map.of(defaultTrends);

  /// Estatura en cm (para el IMC y la escala de la silueta).
  double? get heightCm => _heightCm;

  /// Qué quiere la usuaria en cada medida (reducir, aumentar o solo seguir).
  Map<Measure, Trend> get trends => Map.unmodifiable(_trends);

  Future<void> setHeight(double cm) async {
    _heightCm = cm;
    notifyListeners();
    await _store.writeJson(_heightKey, cm);
  }

  Future<void> setTrend(Measure m, Trend t) async {
    _trends[m] = t;
    notifyListeners();
    await _store.writeJson(_trendsKey, {for (final e in _trends.entries) e.key.name: e.value.name});
  }

  /// Del más antiguo al más reciente.
  List<ProgressRecord> get records => List.unmodifiable([..._records]..sort((a, b) => a.date.compareTo(b.date)));
  List<DailyCheckin> get checkins => List.unmodifiable(_checkins);
  int get evaluationEveryDays => _evaluationEveryDays;

  ProgressRecord? get latest => records.isEmpty ? null : records.last;

  ProgressRecord? byId(String id) {
    for (final r in _records) {
      if (r.id == id) return r;
    }
    return null;
  }

  /// Serie temporal de una medida (solo registros que la tienen).
  List<(DateTime, double)> series(Measure m) => [
        for (final r in records)
          if (r.values[m] case final v?) (r.date, v),
      ];

  double? latestValue(Measure m) {
    final s = series(m);
    return s.isEmpty ? null : s.last.$2;
  }

  /// Cambio entre el primer y el último valor de una medida.
  MeasureDelta? totalChange(Measure m) {
    final s = series(m);
    return s.length < 2 ? null : MeasureDelta(s.first.$2, s.last.$2);
  }

  /// Cambio respecto al registro anterior que tenga esa medida.
  MeasureDelta? lastChange(Measure m) {
    final s = series(m);
    return s.length < 2 ? null : MeasureDelta(s[s.length - 2].$2, s.last.$2);
  }

  DateTime? get nextEvaluation {
    final l = latest;
    return l == null ? null : dateOnly(l.date).add(Duration(days: _evaluationEveryDays));
  }

  /// Días hasta la próxima evaluación (negativo = atrasada). Null si no hay ningún registro.
  int? daysToEvaluation(DateTime now) => nextEvaluation?.difference(dateOnly(now)).inDays;

  bool isEvaluationDue(DateTime now) {
    final d = daysToEvaluation(now);
    return d == null || d <= 0;
  }

  DailyCheckin? checkinFor(DateTime day) {
    final d = dateOnly(day);
    for (final c in _checkins) {
      if (dateOnly(c.date) == d) return c;
    }
    return null;
  }

  Future<ProgressRecord> saveRecord({
    String? id,
    required DateTime date,
    required Map<Measure, double> values,
    required Map<PhotoAngle, String> photoIds,
    String note = '',
  }) async {
    final record = ProgressRecord(id: id ?? newId('rec'), date: date, values: values, photos: photoIds, note: note);
    final old = id == null ? null : byId(id);
    if (old != null) {
      // Borra las fotos que se reemplazaron o quitaron.
      for (final p in old.photos.values) {
        if (!photoIds.values.contains(p)) await photos.delete(p);
      }
    }
    _records.removeWhere((r) => r.id == record.id);
    _records.add(record);
    notifyListeners();
    await _persist();
    return record;
  }

  Future<void> deleteRecord(String id) async {
    final r = byId(id);
    if (r == null) return;
    for (final p in r.photos.values) {
      await photos.delete(p);
    }
    _records.removeWhere((x) => x.id == id);
    notifyListeners();
    await _persist();
  }

  Future<String> savePhoto(Uint8List bytes) => photos.save(bytes);

  Future<void> saveCheckin(DailyCheckin c) async {
    _checkins.removeWhere((x) => dateOnly(x.date) == dateOnly(c.date));
    _checkins.add(c);
    notifyListeners();
    await _store.writeJson(_checkinsKey, _checkins.map((x) => x.toJson()).toList());
  }

  Future<void> setEvaluationEveryDays(int days) async {
    _evaluationEveryDays = days.clamp(7, 60);
    notifyListeners();
    await _store.writeJson(_everyKey, _evaluationEveryDays);
  }

  Future<void> _persist() => _store.writeJson(_recordsKey, _records.map((r) => r.toJson()).toList());
}
