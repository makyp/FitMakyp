import 'package:flutter/foundation.dart';

import '../../../core/data/seed_exercises.dart';
import '../../../core/models/exercise.dart';
import '../../../core/storage/local_store.dart';

/// Biblioteca de ejercicios (independiente de las rutinas).
class LibraryRepository extends ChangeNotifier {
  LibraryRepository(this._store) {
    final raw = _store.readJson(_key);
    if (raw is List) {
      _items = [for (final e in raw) Exercise.fromJson(e as Map<String, dynamic>)];
      _syncBuiltIns();
    } else {
      _items = List.of(seedExercises);
      _persist();
    }
  }

  static const _key = 'exercises';
  final LocalStore _store;
  late List<Exercise> _items;

  /// Los ejercicios incluidos vienen con la app: si una versión nueva añade ejercicios
  /// o mejora sus imágenes, se incorporan sin tocar lo que editó o creó la usuaria.
  void _syncBuiltIns() {
    final seedById = {for (final s in seedExercises) s.id: s};
    final have = {for (final e in _items) e.id};
    final missing = seedExercises.where((s) => !have.contains(s.id)).toList();
    var changed = missing.isNotEmpty;
    _items.addAll(missing);
    for (var i = 0; i < _items.length; i++) {
      final seed = seedById[_items[i].id];
      if (seed == null || _items[i].custom) continue;
      final current = _items[i].media;
      if (current.kind != seed.media.kind || current.src != seed.media.src || current.endSrc != seed.media.endSrc) {
        _items[i] = _items[i].copyWith(media: seed.media);
        changed = true;
      }
    }
    if (changed) _persist();
  }

  List<Exercise> get all => List.unmodifiable(_items..sort((a, b) => a.name.compareTo(b.name)));

  Exercise? byId(String id) {
    for (final e in _items) {
      if (e.id == id) return e;
    }
    return null;
  }

  Future<void> upsert(Exercise exercise) async {
    final i = _items.indexWhere((e) => e.id == exercise.id);
    if (i >= 0) {
      _items[i] = exercise;
    } else {
      _items.add(exercise);
    }
    notifyListeners();
    await _persist();
  }

  Future<void> delete(String id) async {
    _items.removeWhere((e) => e.id == id);
    notifyListeners();
    await _persist();
  }

  Future<void> _persist() => _store.writeJson(_key, _items.map((e) => e.toJson()).toList());
}
