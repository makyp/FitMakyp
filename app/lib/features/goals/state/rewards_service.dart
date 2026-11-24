import '../../challenges/challenge_data.dart';
import '../../challenges/domain/challenges.dart';
import '../../morning/morning_log.dart';
import 'package:flutter/foundation.dart';

import '../../../core/models/body.dart';
import '../../../core/models/goal.dart';
import '../../../core/storage/local_store.dart';
import '../../evolution/state/body_repository.dart';
import '../../habits/state/habits_repository.dart';
import '../../history/state/history_repository.dart';
import '../../pet/state/pet_repository.dart';
import '../../plans/state/plan_repository.dart';
import '../domain/achievements.dart';
import '../domain/rewards.dart';
import 'goals_repository.dart';

/// Une historial, cuerpo, metas y mascota: calcula puntos/nivel y marca metas cumplidas.
class RewardsService extends ChangeNotifier {
  RewardsService({
    required this.history,
    required this.body,
    required this.goals,
    required this.pet,
    required this.plans,
    required this.habits,
    this.store,
  }) {
    final seen = store?.readJson(_seenKey);
    if (seen is List) _seen = {for (final x in seen) '$x'};
    for (final l in [history, body, goals, pet, plans, habits]) {
      l.addListener(_onChange);
    }
    _onChange();
  }

  final HistoryRepository history;
  final BodyRepository body;
  final GoalsRepository goals;
  final PetRepository pet;
  final PlanRepository plans;
  final HabitsRepository habits;
  final LocalStore? store;

  static const _seenKey = 'achievementsSeen';

  /// Insignias ya celebradas (null = primera vez: se marcan todas sin celebrar).
  Set<String>? _seen;
  final List<Achievement> _justUnlocked = [];
  List<AchievementStatus> _achievements = const [];
  int _xp = 0;

  List<AchievementStatus> get achievementStatus => _achievements;

  /// Insignias recién conseguidas, para celebrarlas (se vacía al leerla).
  List<Achievement> takeJustUnlocked() {
    final out = List.of(_justUnlocked);
    _justUnlocked.clear();
    return out;
  }

  /// Metas recién cumplidas, para celebrarlas en la interfaz (se vacía al leerla).
  final List<Goal> _justCompleted = [];
  bool _syncing = false;
  bool _dirty = false;

  List<Goal> takeJustCompleted() {
    final out = List.of(_justCompleted);
    _justCompleted.clear();
    return out;
  }

  /// Retos semanales (también desbloquean premios para la mascota).
  ChallengeInput get challenges => challengeInput(history: history, habits: habits, body: body, store: store);
  ChallengeSummary challengeSummary([DateTime? now]) => summarize(challenges, now ?? DateTime.now());

  /// Volver a calcular (p. ej. tras terminar la rutina matutina).
  Future<void> refresh() => _onChange();

  RewardsInput input([DateTime? now]) {
    final streak = history.streak(plans.trainingWeekdays);
    final st = store;
    return RewardsInput(
      morningDays: st == null ? const {} : MorningLog.days(st),
      challengesCompleted: challengeSummary(now).completed,
      sessions: history.sessions,
      records: body.records,
      checkins: body.checkins,
      goals: goals.all,
      currentStreak: streak.current,
      bestStreak: streak.best,
      now: now ?? DateTime.now(),
      waterGoalDays: habits.waterGoalDays,
      allHabitsDays: habits.allHabitsDays,
    );
  }

  int get xp => _xp;
  int get balance => (xp - pet.spent).clamp(0, 1 << 30);
  int get level => levelFor(xp);
  double get levelProgressValue => levelProgress(xp);
  int get nextLevelAt => levelThreshold(level + 1);

  GoalProgress progressOf(Goal g, [RewardsInput? i]) => goalProgress(
        g,
        i ?? input(),
        latestValue: switch (g.type) {
          GoalType.weight => body.latestValue(Measure.peso),
          GoalType.measure => g.measure == null ? null : body.latestValue(g.measure!),
          _ => null,
        },
      );

  Future<void> _onChange() async {
    if (_syncing) {
      _dirty = true; // se recalcula al terminar
      return;
    }
    _syncing = true;
    try {
      final i = input();
      final reached = [
        for (final g in goals.active)
          if (progressOf(g, i).reached) g.id,
      ];
      if (reached.isNotEmpty) {
        _justCompleted.addAll(await goals.markCompleted(reached, DateTime.now()));
      }
      final fresh = input();
      _xp = totalEarned(fresh);
      await pet.grant(unlockedPrizes(challengeSummary().perfectWeeks));
      _achievements = evaluateAchievements(fresh);
      final unlocked = {for (final a in _achievements) if (a.unlocked) a.achievement.id};
      final seen = _seen;
      if (seen != null) {
        _justUnlocked.addAll([
          for (final a in _achievements)
            if (a.unlocked && !seen.contains(a.achievement.id)) a.achievement,
        ]);
      }
      if (seen == null || !seen.containsAll(unlocked)) {
        _seen = {...?seen, ...unlocked};
        await store?.writeJson(_seenKey, _seen!.toList());
      }
    } finally {
      _syncing = false;
    }
    notifyListeners();
    if (_dirty) {
      _dirty = false;
      await _onChange();
    }
  }

  @override
  void dispose() {
    for (final l in [history, body, goals, pet, plans, habits]) {
      l.removeListener(_onChange);
    }
    super.dispose();
  }
}
