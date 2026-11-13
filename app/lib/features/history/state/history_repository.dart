import 'package:flutter/foundation.dart';

import '../../../core/models/session.dart';
import '../../../core/storage/local_store.dart';
import '../../../core/utils/format.dart';
import '../domain/streak.dart';

/// Historial de entrenamientos terminados.
class HistoryRepository extends ChangeNotifier {
  HistoryRepository(this._store) {
    final raw = _store.readJson(_key);
    if (raw is List) {
      _sessions = [for (final s in raw) WorkoutSession.fromJson(s as Map<String, dynamic>)];
    }
  }

  static const _key = 'history';
  final LocalStore _store;
  List<WorkoutSession> _sessions = [];

  /// Más recientes primero.
  List<WorkoutSession> get sessions =>
      List.unmodifiable([..._sessions]..sort((a, b) => b.startedAt.compareTo(a.startedAt)));

  WorkoutSession? byId(String id) {
    for (final s in _sessions) {
      if (s.id == id) return s;
    }
    return null;
  }

  /// Días en los que se completó al menos una serie.
  Set<DateTime> get trainedDates => {
        for (final s in _sessions)
          if (s.completedSets > 0) dateOnly(s.startedAt),
      };

  StreakStats streak(Set<int> trainingWeekdays) =>
      computeStreak(trainedDates: trainedDates, trainingWeekdays: trainingWeekdays, today: DateTime.now());

  /// Guarda qué se hizo con los estiramientos de una sesión terminada.
  Future<void> setCooldown(String sessionId, String status) async {
    final s = byId(sessionId);
    if (s != null) await add(s.copyWith(cooldown: status));
  }

  Future<void> add(WorkoutSession session) async {
    _sessions.removeWhere((s) => s.id == session.id);
    _sessions.add(session);
    notifyListeners();
    await _store.writeJson(_key, _sessions.map((s) => s.toJson()).toList());
  }
}
