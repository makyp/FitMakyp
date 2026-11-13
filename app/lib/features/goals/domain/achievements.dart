/// Insignias (logros). Se calculan a partir de lo que ya hiciste: nunca se pierden. Lógica pura.
library;

import '../../workout/domain/strength.dart';
import 'rewards.dart';

enum AchievementGroup {
  entreno('Entrenamientos'),
  constancia('Constancia'),
  cuidado('Calentar y estirar'),
  fuerza('Fuerza'),
  cuerpo('Seguimiento'),
  habitos('Hábitos');

  const AchievementGroup(this.label);
  final String label;
}

class Achievement {
  const Achievement({
    required this.id,
    required this.emoji,
    required this.title,
    required this.description,
    required this.group,
    required this.target,
    this.points = 0,
  });

  final String id;
  final String emoji;
  final String title;
  final String description;
  final AchievementGroup group;

  /// Cantidad necesaria (entrenos, días, récords…).
  final int target;

  /// Puntos extra para la mascota (0 en las de racha: esos ya se suman aparte).
  final int points;
}

class AchievementStatus {
  const AchievementStatus(this.achievement, this.current);
  final Achievement achievement;
  final int current;
  bool get unlocked => current >= achievement.target;
  double get fraction => (current / achievement.target).clamp(0.0, 1.0);
  String get progressText => '${current.clamp(0, achievement.target)} / ${achievement.target}';
}

const achievements = <Achievement>[
  Achievement(id: 'entreno_1', emoji: '🥇', title: 'Primer paso', description: 'Completa tu primer entrenamiento', group: AchievementGroup.entreno, target: 1, points: 20),
  Achievement(id: 'entreno_10', emoji: '💪', title: 'Diez y contando', description: '10 entrenamientos', group: AchievementGroup.entreno, target: 10, points: 50),
  Achievement(id: 'entreno_25', emoji: '🏋️', title: 'Hábito creado', description: '25 entrenamientos', group: AchievementGroup.entreno, target: 25, points: 100),
  Achievement(id: 'entreno_50', emoji: '🔥', title: 'Medio centenar', description: '50 entrenamientos', group: AchievementGroup.entreno, target: 50, points: 200),
  Achievement(id: 'entreno_100', emoji: '👑', title: 'Reina del gym', description: '100 entrenamientos', group: AchievementGroup.entreno, target: 100, points: 400),
  Achievement(id: 'completos_10', emoji: '✅', title: 'Sin dejar series', description: '10 entrenamientos completos al 100 %', group: AchievementGroup.entreno, target: 10, points: 60),
  Achievement(id: 'madrugadora', emoji: '🌅', title: 'Madrugadora', description: 'Entrena antes de las 8:00', group: AchievementGroup.entreno, target: 1, points: 30),
  Achievement(id: 'nocturna', emoji: '🌙', title: 'Búho', description: 'Entrena después de las 21:00', group: AchievementGroup.entreno, target: 1, points: 30),
  Achievement(id: 'racha_3', emoji: '✨', title: 'Arrancando', description: 'Racha de 3 días de entreno', group: AchievementGroup.constancia, target: 3),
  Achievement(id: 'racha_7', emoji: '⚡', title: 'Semana imparable', description: 'Racha de 7 días de entreno', group: AchievementGroup.constancia, target: 7),
  Achievement(id: 'racha_30', emoji: '🌟', title: 'Un mes sin fallar', description: 'Racha de 30 días de entreno', group: AchievementGroup.constancia, target: 30),
  Achievement(id: 'mes_12', emoji: '📅', title: 'Mes constante', description: '12 entrenamientos en un mismo mes', group: AchievementGroup.constancia, target: 12, points: 150),
  Achievement(id: 'calienta_10', emoji: '🔥', title: 'Siempre calentita', description: 'Calienta antes de 10 entrenamientos', group: AchievementGroup.cuidado, target: 10, points: 60),
  Achievement(id: 'estira_10', emoji: '🧘', title: 'Flexible', description: 'Estira después de 10 entrenamientos', group: AchievementGroup.cuidado, target: 10, points: 60),
  Achievement(id: 'record_1', emoji: '🏆', title: 'Primer récord', description: 'Supera tu mejor marca en un ejercicio', group: AchievementGroup.fuerza, target: 1, points: 40),
  Achievement(id: 'record_10', emoji: '🚀', title: 'Cada vez más fuerte', description: '10 récords superados', group: AchievementGroup.fuerza, target: 10, points: 120),
  Achievement(id: 'registro_1', emoji: '📏', title: 'Punto de partida', description: 'Haz tu primer registro de progreso', group: AchievementGroup.cuerpo, target: 1, points: 20),
  Achievement(id: 'registro_6', emoji: '📈', title: 'Seguimiento fiel', description: '6 registros de progreso', group: AchievementGroup.cuerpo, target: 6, points: 80),
  Achievement(id: 'agua_7', emoji: '💧', title: 'Hidratada', description: 'Cumple tu meta de agua 7 días', group: AchievementGroup.habitos, target: 7, points: 50),
  Achievement(id: 'agua_30', emoji: '🌊', title: 'Agua de oro', description: 'Cumple tu meta de agua 30 días', group: AchievementGroup.habitos, target: 30, points: 150),
  Achievement(id: 'habitos_7', emoji: '🌸', title: 'Días redondos', description: 'Cumple todos tus hábitos 7 días', group: AchievementGroup.habitos, target: 7, points: 70),
];

List<AchievementStatus> evaluateAchievements(RewardsInput i) {
  final done = i.sessions.where((s) => s.completedSets > 0).toList()..sort((a, b) => a.startedAt.compareTo(b.startedAt));
  final full = done.where((s) => s.completedSets >= s.plannedSets).length;
  final early = done.any((s) => s.startedAt.hour < 8) ? 1 : 0;
  final late = done.any((s) => s.startedAt.hour >= 21) ? 1 : 0;
  final perMonth = <String, int>{};
  for (final s in done) {
    final k = '${s.startedAt.year}-${s.startedAt.month}';
    perMonth[k] = (perMonth[k] ?? 0) + 1;
  }
  final bestMonth = perMonth.values.fold(0, (a, b) => a > b ? a : b);
  bool counts(String? st) => st == 'done' || st == 'alreadyDone';
  final warm = done.where((s) => counts(s.warmup)).length;
  final cool = done.where((s) => counts(s.cooldown)).length;
  var records = 0;
  for (final s in done) {
    records += newRecordsIn(s, done).length;
  }

  int current(Achievement a) => switch (a.id) {
        'entreno_1' || 'entreno_10' || 'entreno_25' || 'entreno_50' || 'entreno_100' => done.length,
        'completos_10' => full,
        'madrugadora' => early,
        'nocturna' => late,
        'racha_3' || 'racha_7' || 'racha_30' => i.bestStreak,
        'mes_12' => bestMonth,
        'calienta_10' => warm,
        'estira_10' => cool,
        'record_1' || 'record_10' => records,
        'registro_1' || 'registro_6' => i.records.length,
        'agua_7' || 'agua_30' => i.waterGoalDays.length,
        'habitos_7' => i.allHabitsDays.length,
        _ => 0,
      };

  return [for (final a in achievements) AchievementStatus(a, current(a))];
}

/// Puntos de las insignias conseguidas.
List<PointsEntry> achievementPoints(List<AchievementStatus> list) => [
      for (final s in list)
        if (s.unlocked && s.achievement.points > 0) PointsEntry('Insignia: ${s.achievement.title}', s.achievement.points),
    ];
