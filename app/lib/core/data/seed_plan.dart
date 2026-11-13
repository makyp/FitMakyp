import '../models/exercise.dart';
import '../models/plan.dart';

/// Rutina inicial de cinco días. Es solo la configuración de partida: todo se puede editar.
WorkoutPlan buildSeedPlan() {
  var n = 0;
  WorkoutExercise we(String exerciseId, int sets, SetTarget target) =>
      WorkoutExercise(id: 'we_${n++}', exerciseId: exerciseId, sets: sets, target: target);

  final now = DateTime.now();
  return WorkoutPlan(
    id: 'plan_inicial',
    name: 'Mi rutina',
    createdAt: now,
    updatedAt: now,
    days: [
      WorkoutDay(
        id: 'day_1',
        weekday: 1,
        kind: DayKind.training,
        title: 'Pecho, hombros y tríceps',
        exercises: [
          we('press_pecho_en_banco', 4, const SetTarget.reps(12)),
          we('aperturas_con_mancuernas', 3, const SetTarget.reps(12)),
          we('press_militar', 3, const SetTarget.reps(10, max: 12)),
          we('elevaciones_laterales', 3, const SetTarget.reps(12, max: 15)),
          we('extension_triceps_sobre_cabeza', 3, const SetTarget.reps(12)),
          we('flexiones', 2, const SetTarget.reps(8, max: 10)),
        ],
      ),
      WorkoutDay(
        id: 'day_2',
        weekday: 2,
        kind: DayKind.training,
        title: 'Glúteos y piernas',
        exercises: [
          we('hip_thrust', 4, const SetTarget.reps(12, max: 15)),
          we('sentadilla_bulgara', 3, const SetTarget.reps(10, perSide: true)),
          we('peso_muerto_rumano', 3, const SetTarget.reps(12)),
          we('sentadilla_sumo', 3, const SetTarget.reps(12)),
          we('abduccion_de_cadera', 3, const SetTarget.reps(15, max: 20)),
        ],
      ),
      WorkoutDay(
        id: 'day_3',
        weekday: 3,
        kind: DayKind.training,
        title: 'Abdomen y cardio',
        exercises: [
          we('dead_bug', 3, const SetTarget.reps(12)),
          we('plancha_frontal', 3, const SetTarget.seconds(30)),
          we('plancha_lateral', 3, const SetTarget.seconds(20, perSide: true)),
          we('crunch_inverso', 3, const SetTarget.reps(12)),
          we('bird_dog', 3, const SetTarget.reps(12)),
          we('bicicleta_estatica', 1, const SetTarget.seconds(25 * 60, max: 30 * 60)),
        ],
      ),
      WorkoutDay(
        id: 'day_4',
        weekday: 4,
        kind: DayKind.training,
        title: 'Pecho, espalda y brazos',
        exercises: [
          we('press_pecho_en_banco', 3, const SetTarget.reps(12)),
          we('remo_con_mancuerna', 3, const SetTarget.reps(12)),
          we('press_de_hombros', 3, const SetTarget.reps(12)),
          we('curl_de_biceps', 3, const SetTarget.reps(12)),
          we('curl_martillo', 2, const SetTarget.reps(12)),
          we('patada_de_triceps', 3, const SetTarget.reps(12)),
        ],
      ),
      WorkoutDay(
        id: 'day_5',
        weekday: 5,
        kind: DayKind.training,
        title: 'Glúteos, piernas y cardio',
        exercises: [
          we('hip_thrust', 4, const SetTarget.reps(12)),
          we('sentadilla_bulgara', 3, const SetTarget.reps(10, perSide: true)),
          we('peso_muerto_rumano', 3, const SetTarget.reps(12)),
          we('puente_de_gluteos', 3, const SetTarget.reps(15)),
          we('sentadilla_sumo', 2, const SetTarget.reps(15)),
          we('bicicleta_estatica', 1, const SetTarget.seconds(20 * 60, max: 25 * 60)),
        ],
      ),
      const WorkoutDay(id: 'day_6', weekday: 6, kind: DayKind.rest, title: 'Recuperación activa'),
      const WorkoutDay(id: 'day_7', weekday: 7, kind: DayKind.rest, title: 'Descanso'),
    ],
  );
}
