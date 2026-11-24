import 'package:fitmakyp/core/models/habits.dart';
import 'package:fitmakyp/core/notifications/reminders.dart';
import 'package:fitmakyp/core/storage/local_store.dart';
import 'package:fitmakyp/features/goals/domain/rewards.dart';
import 'package:fitmakyp/features/habits/state/habits_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('recordatorios de agua: sin horas pasadas y sin hoy si ya se cumplió la meta', () {
    const s = HabitsSettings(reminderStartHour: 9, reminderEndHour: 21, reminderEveryHours: 4);
    expect(s.reminderHours, [9, 13, 17, 21]);
    final now = DateTime(2026, 11, 10, 14, 30);
    final t = waterReminderTimes(now: now, settings: s, goalMetToday: false, days: 2);
    expect(t.first, DateTime(2026, 11, 10, 17));
    expect(t.length, 2 + 4);
    final met = waterReminderTimes(now: now, settings: s, goalMetToday: true, days: 2);
    expect(met.first, DateTime(2026, 11, 11, 9));
    expect(waterReminderTimes(now: now, settings: s.copyWith(waterReminders: false), goalMetToday: false), isEmpty);
  });

  test('aviso de evaluación: 10:00 del día que toca, o mañana si ya pasó', () {
    final now = DateTime(2026, 11, 10, 12);
    expect(evaluationReminderAt(nextEvaluation: DateTime(2026, 11, 16), now: now, enabled: true), DateTime(2026, 11, 16, 10));
    expect(evaluationReminderAt(nextEvaluation: DateTime(2026, 11, 8), now: now, enabled: true), DateTime(2026, 11, 11, 10));
    expect(evaluationReminderAt(nextEvaluation: null, now: now, enabled: true), isNull);
    expect(evaluationReminderAt(nextEvaluation: DateTime(2026, 11, 16), now: now, enabled: false), isNull);
  });

  test('agua y hábitos se guardan y dan puntos', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await LocalStore.open();
    final h = HabitsRepository(store);
    final day = DateTime(2026, 11, 10, 9);
    for (var i = 0; i < 8; i++) {
      await h.addGlass(day);
    }
    expect(h.waterGoalMet(day), isTrue);
    await h.addGlass(day, -20);
    expect(h.glasses(day), 0, reason: 'nunca baja de 0');
    for (var i = 0; i < 8; i++) {
      await h.addGlass(day);
    }

    for (final x in h.activeHabits) {
      await h.toggleHabit(x.id, day);
    }
    expect(h.allHabitsDays, {DateTime(2026, 11, 10)});

    // Se recargan desde el almacenamiento.
    final h2 = HabitsRepository(store);
    expect(h2.glasses(day), 8);

    final pts = totalEarned(RewardsInput(
      sessions: const [],
      records: const [],
      checkins: const [],
      goals: const [],
      currentStreak: 0,
      bestStreak: 0,
      now: day,
      waterGoalDays: h2.waterGoalDays,
      allHabitsDays: h2.allHabitsDays,
    ));
    expect(pts, PointRules.waterDay + PointRules.habitsDay);
  });
}
