/// Retos semanales (lunes a domingo). Se calculan con lo que ya registras:
/// no hay que "apuntarse" y nunca se pierden puntos. Lógica pura.
library;

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);
DateTime weekStart(DateTime d) => DateTime(d.year, d.month, d.day - (d.weekday - 1));

/// Días (solo fecha) en que pasó cada cosa.
class ChallengeInput {
  const ChallengeInput({
    this.trained = const {},
    this.water = const {},
    this.morning = const {},
    this.checkins = const {},
    this.allHabits = const {},
    this.hasHabits = false,
  });

  final Set<DateTime> trained;
  final Set<DateTime> water;
  final Set<DateTime> morning;
  final Set<DateTime> checkins;
  final Set<DateTime> allHabits;
  final bool hasHabits;

  /// La fecha más antigua con algún dato (para no contar semanas vacías de antes de usar la app).
  DateTime? get firstDay {
    final all = [...trained, ...water, ...morning, ...checkins];
    if (all.isEmpty) return null;
    return all.reduce((a, b) => a.isBefore(b) ? a : b);
  }
}

enum ChallengeKind {
  entrenar('Entrena 3 días', '💪', 3),
  agua('Cumple tu meta de agua 5 días', '💧', 5),
  matutina('Haz 3 rutinas matutinas', '🌅', 3),
  registro('Haz tu registro diario 5 días', '🎭', 5),
  habitos('Cumple todos tus hábitos 3 días', '✨', 3);

  const ChallengeKind(this.title, this.emoji, this.target);
  final String title;
  final String emoji;
  final int target;

  Set<DateTime> days(ChallengeInput i) => switch (this) {
        ChallengeKind.entrenar => i.trained,
        ChallengeKind.agua => i.water,
        ChallengeKind.matutina => i.morning,
        ChallengeKind.registro => i.checkins,
        ChallengeKind.habitos => i.allHabits,
      };

  bool available(ChallengeInput i) => switch (this) {
        ChallengeKind.habitos => i.hasHabits,
        _ => true,
      };
}

class ChallengeStatus {
  const ChallengeStatus(this.kind, this.progress);
  final ChallengeKind kind;
  final int progress;
  bool get done => progress >= kind.target;
}

/// Los 3 retos de la semana que empieza en [monday]: entrenar siempre y otros 2 que van rotando.
List<ChallengeKind> challengesOfWeek(DateTime monday, ChallengeInput i) {
  final pool = [for (final k in ChallengeKind.values) if (k != ChallengeKind.entrenar && k.available(i)) k];
  final week = DateTime.utc(monday.year, monday.month, monday.day).millisecondsSinceEpoch ~/ (7 * 86400000);
  final picks = <ChallengeKind>[ChallengeKind.entrenar];
  for (var k = 0; k < pool.length && picks.length < 3; k++) {
    picks.add(pool[(week * 2 + k) % pool.length]);
  }
  return picks;
}

List<ChallengeStatus> weekStatus(DateTime monday, ChallengeInput i) {
  final end = monday.add(const Duration(days: 7));
  return [
    for (final k in challengesOfWeek(monday, i))
      ChallengeStatus(
        k,
        k.days(i).map(_day).where((d) => !d.isBefore(monday) && d.isBefore(end)).toSet().length.clamp(0, k.target),
      ),
  ];
}

class ChallengeSummary {
  const ChallengeSummary({required this.completed, required this.perfectWeeks});

  /// Retos cumplidos en total.
  final int completed;

  /// Semanas con los 3 retos cumplidos (cada una desbloquea un premio).
  final int perfectWeeks;
}

/// Todas las semanas desde el primer dato hasta [now] (la semana en curso cuenta si ya se cumplió).
ChallengeSummary summarize(ChallengeInput i, DateTime now) {
  final first = i.firstDay;
  if (first == null) return const ChallengeSummary(completed: 0, perfectWeeks: 0);
  var monday = weekStart(first);
  final last = weekStart(now);
  var completed = 0, perfect = 0;
  while (!monday.isAfter(last)) {
    final st = weekStatus(monday, i);
    final done = st.where((s) => s.done).length;
    completed += done;
    if (done == st.length) perfect++;
    monday = DateTime(monday.year, monday.month, monday.day + 7);
  }
  return ChallengeSummary(completed: completed, perfectWeeks: perfect);
}

/// Premios para la mascota, en orden: uno por cada semana con todos los retos.
const challengePrizes = ['tiara_estrellas', 'banda_campeona', 'gafas_corazon', 'pompones', 'chaqueta_dorada', 'arcoiris'];

List<String> unlockedPrizes(int perfectWeeks) => challengePrizes.take(perfectWeeks).toList();
