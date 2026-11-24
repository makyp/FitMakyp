import '../../core/models/exercise.dart';
import '../../core/models/plan.dart';

/// Sesiones de boxeo para principiantes con saco y pesas. Lógica pura.
/// Rondas de 2 minutos con 1 minuto de descanso, como en el boxeo de verdad.
class BoxingSession {
  const BoxingSession(this.title, this.summary, this.exercises);
  final String title;
  final String summary;
  final List<(String, int, SetTarget, int)> exercises; // id, series/rondas, objetivo, descanso (s)
}

const boxingSessions = [
  BoxingSession(
    'Boxeo · técnica y saco',
    'Guardia, jab, directo, la combinación 1-2 y defensa. Termina con core.',
    [
      ('boxeo_guardia', 2, SetTarget.seconds(120), 60),
      ('boxeo_jab', 3, SetTarget.seconds(120), 60),
      ('boxeo_directo', 2, SetTarget.seconds(120), 60),
      ('boxeo_uno_dos', 3, SetTarget.seconds(120), 60),
      ('boxeo_esquiva', 2, SetTarget.seconds(60), 45),
      ('plancha_frontal', 3, SetTarget.seconds(30), 45),
    ],
  ),
  BoxingSession(
    'Boxeo · saco y fuerza',
    'Ganchos, uppercuts y la combinación 1-2-3, y fuerza con mancuernas.',
    [
      ('boxeo_guardia', 1, SetTarget.seconds(120), 60),
      ('boxeo_gancho', 2, SetTarget.seconds(120), 60),
      ('boxeo_uppercut', 2, SetTarget.seconds(120), 60),
      ('boxeo_combo_123', 3, SetTarget.seconds(120), 60),
      ('sentadilla_mancuernas', 3, SetTarget.reps(12), 75),
      ('remo_con_mancuerna', 3, SetTarget.reps(12, perSide: true), 75),
      ('press_de_hombros', 3, SetTarget.reps(10), 75),
      ('dead_bug', 3, SetTarget.reps(12), 45),
    ],
  ),
];

/// Minutos aproximados de una sesión (sin contar calentamiento ni estiramientos).
int boxingMinutes(BoxingSession s) {
  var sec = 0;
  for (final (_, sets, t, rest) in s.exercises) {
    final work = t.isTime ? t.min : 45 * (t.perSide ? 2 : 1);
    sec += sets * work + (sets - 1) * rest + 30;
  }
  return (sec / 60).round();
}

/// El día [weekday] convertido en un día de boxeo (alterna las dos sesiones según el orden).
WorkoutDay boxingDay(WorkoutDay day, int order) {
  final s = boxingSessions[order % boxingSessions.length];
  return day.copyWith(
    kind: DayKind.training,
    title: s.title,
    exercises: [
      for (final (i, (id, sets, target, rest)) in s.exercises.indexed)
        WorkoutExercise(id: 'box_${day.weekday}_$i', exerciseId: id, sets: sets, target: target, restSeconds: rest),
    ],
  );
}

bool isBoxingDay(WorkoutDay d) => d.exercises.any((e) => e.exerciseId.startsWith('boxeo_'));
