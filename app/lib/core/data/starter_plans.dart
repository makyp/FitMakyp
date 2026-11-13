import '../models/exercise.dart';
import '../models/plan.dart';

/// Rutinas de partida para personas nuevas, según lo que eligen en la bienvenida.
/// Son solo un punto de partida: todo se puede editar después.
enum StarterPlace {
  mancuernas('Con mancuernas', 'Mancuernas y un banco o silla firme'),
  casa('En casa, sin equipo', 'Solo tu cuerpo y una esterilla');

  const StarterPlace(this.label, this.description);
  final String label;
  final String description;
}

enum StarterLevel {
  principiante('Estoy empezando'),
  intermedio('Ya entreno');

  const StarterLevel(this.label);
  final String label;
}

enum StarterFocus {
  equilibrado('Todo el cuerpo por igual'),
  gluteo('Más glúteo y pierna');

  const StarterFocus(this.label);
  final String label;
}

/// Días de la semana para [n] entrenos.
List<int> starterWeekdays(int n) => switch (n.clamp(2, 5)) {
      2 => [1, 4],
      3 => [1, 3, 5],
      4 => [1, 2, 4, 5],
      _ => [1, 2, 3, 4, 5],
    };

WorkoutPlan buildStarterPlan({
  required int daysPerWeek,
  required StarterPlace place,
  required StarterLevel level,
  required StarterFocus focus,
  DateTime? now,
}) {
  var n = 0;
  final pro = level == StarterLevel.intermedio;
  final home = place == StarterPlace.casa;
  WorkoutExercise we(String id, {bool main = false, SetTarget? target}) => WorkoutExercise(
        id: 'we_${n++}',
        exerciseId: id,
        sets: main && pro ? 4 : 3,
        target: target ?? (main ? const SetTarget.reps(10, max: 12) : const SetTarget.reps(12, max: 15)),
      );
  final plank = SetTarget.seconds(pro ? 40 : 30);
  final sidePlank = SetTarget.seconds(pro ? 25 : 20, perSide: true);

  // Bloques de ejercicios.
  final lowerA = home
      ? [we('sentadilla', main: true), we('puente_de_gluteos', main: true), we(pro ? 'sentadilla_salto' : 'patada_de_gluteo'), we('abduccion_de_cadera'), we('elevacion_talones')]
      : [we('sentadilla_mancuernas', main: true), we('hip_thrust', main: true), we('peso_muerto_rumano'), we('zancada_atras'), we('abduccion_de_cadera')];
  final lowerB = home
      ? [we('puente_de_gluteos', main: true), we(pro ? 'puente_una_pierna' : 'patada_de_gluteo'), we('sentadilla'), we('abduccion_de_cadera'), we('escaladores', target: const SetTarget.seconds(30))]
      : [we('hip_thrust', main: true), we(pro ? 'sentadilla_bulgara' : 'step_up', main: true, target: const SetTarget.reps(10, perSide: true)), we('sentadilla_sumo'), we(pro ? 'puente_una_pierna' : 'puente_de_gluteos'), we('patada_de_gluteo')];
  final upperA = home
      ? [we(pro ? 'flexiones' : 'flexiones_inclinadas', main: true), we('superman'), we('fondos_en_banco'), we('plancha_frontal', target: plank), we('escaladores', target: const SetTarget.seconds(30))]
      : [we('press_pecho_en_banco', main: true), we('remo_con_mancuerna', main: true), we('press_de_hombros'), we('elevaciones_laterales'), we('curl_de_biceps'), we('extension_triceps_sobre_cabeza')];
  final upperB = home
      ? [we('flexiones_inclinadas', main: true), we('superman'), we('fondos_en_banco'), we('bird_dog'), we('plancha_lateral', target: sidePlank)]
      : [we(pro ? 'press_inclinado' : 'flexiones_inclinadas', main: true), we(pro ? 'remo_dos_mancuernas' : 'remo_con_mancuerna', main: true), we('pajaros'), we('curl_martillo'), we('patada_de_triceps')];
  final core = [we('dead_bug'), we('plancha_frontal', target: plank), we('crunch_inverso'), we('plancha_lateral', target: sidePlank), we('bird_dog')];
  final fullA = home
      ? [we('sentadilla', main: true), we('flexiones_inclinadas', main: true), we('puente_de_gluteos'), we('superman'), we('plancha_frontal', target: plank)]
      : [we('sentadilla_mancuernas', main: true), we('press_pecho_en_banco', main: true), we('hip_thrust'), we('remo_con_mancuerna'), we('press_de_hombros'), we('plancha_frontal', target: plank)];
  final fullB = home
      ? [we('puente_de_gluteos', main: true), we('superman'), we('patada_de_gluteo'), we('fondos_en_banco'), we('dead_bug'), we('escaladores', target: const SetTarget.seconds(30))]
      : [we('peso_muerto_rumano', main: true), we('flexiones_inclinadas'), we('zancada_atras'), we('remo_con_mancuerna'), we('elevaciones_laterales'), we('dead_bug')];

  final glute = focus == StarterFocus.gluteo;
  final List<(String, List<WorkoutExercise>)> sessions = switch (daysPerWeek.clamp(2, 5)) {
    2 => [('Cuerpo completo A', fullA), ('Cuerpo completo B', fullB)],
    3 => glute
        ? [('Glúteos y piernas', lowerA), ('Tren superior y abdomen', [...upperA.take(4), ...core.take(2)]), ('Glúteos y piernas B', lowerB)]
        : [('Cuerpo completo A', fullA), ('Cuerpo completo B', fullB), ('Cuerpo completo C', [...lowerB.take(3), ...upperB.take(3)])],
    4 => [('Glúteos y piernas', lowerA), ('Tren superior', upperA), ('Glúteos y piernas B', lowerB), ('Tren superior y abdomen', [...upperB.take(4), ...core.take(2)])],
    _ => glute
        ? [('Glúteos y piernas', lowerA), ('Tren superior', upperA), ('Abdomen y core', core), ('Glúteos y piernas B', lowerB), ('Tren superior B', upperB)]
        : [('Tren inferior', lowerA), ('Pecho, hombros y brazos', upperA), ('Abdomen y core', core), ('Espalda y brazos', upperB), ('Tren inferior B', lowerB)],
  };

  final days = starterWeekdays(daysPerWeek);
  final t = now ?? DateTime.now();
  return WorkoutPlan(
    id: 'plan_${t.millisecondsSinceEpoch}',
    name: 'Mi rutina',
    createdAt: t,
    updatedAt: t,
    days: [
      for (var w = 1; w <= 7; w++)
        if (days.contains(w))
          WorkoutDay(
            id: 'day_$w',
            weekday: w,
            kind: DayKind.training,
            title: sessions[days.indexOf(w)].$1,
            exercises: sessions[days.indexOf(w)].$2,
          )
        else
          WorkoutDay(id: 'day_$w', weekday: w, kind: DayKind.rest, title: w == 6 ? 'Recuperación activa' : 'Descanso'),
    ],
  );
}
