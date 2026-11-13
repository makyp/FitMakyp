import 'package:flutter/foundation.dart';

import '../../../core/models/goal.dart';
import '../../../core/storage/local_store.dart';

class GoalsRepository extends ChangeNotifier {
  GoalsRepository(this._store) {
    final raw = _store.readJson(_key);
    if (raw is List) _goals = [for (final g in raw) Goal.fromJson(g as Map<String, dynamic>)];
  }

  static const _key = 'goals';
  final LocalStore _store;
  List<Goal> _goals = [];

  List<Goal> get all => List.unmodifiable(_goals);
  List<Goal> get active => _goals.where((g) => !g.isCompleted).toList();
  List<Goal> get completed => _goals.where((g) => g.isCompleted).toList()
    ..sort((a, b) => b.completedAt!.compareTo(a.completedAt!));

  Future<void> add(Goal g) async {
    _goals.add(g);
    notifyListeners();
    await _persist();
  }

  Future<void> remove(String id) async {
    _goals.removeWhere((g) => g.id == id);
    notifyListeners();
    await _persist();
  }

  /// Marca como cumplidas las metas indicadas. Devuelve las que acaban de cumplirse.
  Future<List<Goal>> markCompleted(Iterable<String> ids, DateTime at) async {
    final done = <Goal>[];
    _goals = [
      for (final g in _goals)
        if (!g.isCompleted && ids.contains(g.id)) (done..add(g.complete(at))).last else g,
    ];
    if (done.isNotEmpty) {
      notifyListeners();
      await _persist();
    }
    return done;
  }

  Future<void> _persist() => _store.writeJson(_key, _goals.map((g) => g.toJson()).toList());
}
