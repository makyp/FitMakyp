/// Calentamiento y estiramientos (vuelta a la calma) de cada entrenamiento.
/// Se arman solos según los músculos del día. Lógica pura.
library;

import '../../../core/models/exercise.dart';

enum RoutinePhase {
  warmup('Calentamiento', 'calentamiento'),
  cooldown('Estiramientos', 'estiramientos');

  const RoutinePhase(this.label, this.lower);
  final String label;
  final String lower;
}

/// Qué se hizo con el calentamiento o los estiramientos de una sesión.
enum PhaseStatus {
  /// Hecho con la guía de la app.
  done('Hecho'),

  /// La usuaria ya lo había hecho por su cuenta.
  alreadyDone('Ya lo había hecho'),
  skipped('Omitido');

  const PhaseStatus(this.label);
  final String label;

  bool get counts => this != PhaseStatus.skipped;
}

enum BodyRegion { general, lower, upper, core }

class WarmupMove {
  const WarmupMove({
    required this.id,
    required this.name,
    required this.seconds,
    required this.steps,
    required this.region,
    this.perSide = false,
  });

  final String id;
  final String name;

  /// Duración (por lado si [perSide]).
  final int seconds;
  final List<String> steps;
  final BodyRegion region;
  final bool perSide;

  int get totalSeconds => perSide ? seconds * 2 : seconds;

  /// Fotos de inicio y final (Free Exercise DB, dominio público). La respiración no tiene.
  bool get hasPhoto => id != 'respiracion';
  String get photoStart => 'assets/warmup/${id}_start.jpg';
  String get photoEnd => 'assets/warmup/${id}_end.jpg';
}

// ------------------------------------------------------------ calentamiento

const _march = WarmupMove(
  id: 'marcha',
  name: 'Marcha en el sitio',
  seconds: 60,
  region: BodyRegion.general,
  steps: ['Sube las rodillas a un ritmo cómodo.', 'Mueve los brazos al paso.', 'Ve subiendo el ritmo poco a poco.'],
);
const _jacks = WarmupMove(
  id: 'jacks_suaves',
  name: 'Saltos de tijera suaves',
  seconds: 40,
  region: BodyRegion.general,
  steps: ['Abre y cierra piernas y brazos a la vez.', 'Sin impacto: da un paso al lado en vez de saltar si lo prefieres.'],
);
const _hips = WarmupMove(
  id: 'circulos_cadera',
  name: 'Círculos de cadera',
  seconds: 30,
  region: BodyRegion.general,
  steps: ['De pie, apóyate en una pared o silla si lo necesitas.', 'Sube una rodilla y dibuja círculos amplios hacia fuera.', 'A mitad de tiempo, cambia de pierna.'],
);
const _armCircles = WarmupMove(
  id: 'circulos_brazos',
  name: 'Círculos de brazos',
  seconds: 40,
  region: BodyRegion.upper,
  steps: ['Brazos extendidos a los lados.', 'Círculos pequeños que se van haciendo grandes.', 'A mitad de tiempo, cambia de sentido.'],
);
const _hugs = WarmupMove(
  id: 'abrazos',
  name: 'Aperturas y abrazos',
  seconds: 30,
  region: BodyRegion.upper,
  steps: ['Abre los brazos llevando el pecho adelante.', 'Ciérralos dándote un abrazo.', 'Alterna qué brazo queda arriba.'],
);
const _wallPush = WarmupMove(
  id: 'flexion_pared',
  name: 'Flexiones inclinadas',
  seconds: 40,
  region: BodyRegion.upper,
  steps: ['Manos en la pared, una mesa o un banco firme.', 'Baja el pecho hacia la pared y empuja de vuelta.', 'Ritmo lento y controlado.'],
);
const _catCow = WarmupMove(
  id: 'gato_camello',
  name: 'Gato-camello',
  seconds: 40,
  region: BodyRegion.core,
  steps: ['En cuatro apoyos.', 'Redondea la espalda mirando al ombligo.', 'Luego húndela suave mirando al frente. Respira en cada cambio.'],
);
const _legSwings = WarmupMove(
  id: 'balanceo_piernas',
  name: 'Balanceo de pierna',
  seconds: 20,
  perSide: true,
  region: BodyRegion.lower,
  steps: ['Apóyate en una pared o silla.', 'Balancea la pierna adelante y atrás, sin forzar.', 'Luego cambia de pierna.'],
);
const _airSquat = WarmupMove(
  id: 'sentadilla_aire',
  name: 'Sentadilla lenta sin peso',
  seconds: 40,
  region: BodyRegion.lower,
  steps: ['Pies al ancho de hombros.', 'Baja despacio hasta donde estés cómoda.', 'Rodillas en la dirección de los pies.'],
);
const _bridge = WarmupMove(
  id: 'puente_activacion',
  name: 'Puente de glúteo (activación)',
  seconds: 40,
  region: BodyRegion.lower,
  steps: ['Boca arriba, rodillas dobladas.', 'Sube la cadera apretando glúteos.', 'Mantén 2 s arriba y baja despacio.'],
);
const _deadBug = WarmupMove(
  id: 'dead_bug_suave',
  name: 'Dead bug lento',
  seconds: 40,
  region: BodyRegion.core,
  steps: ['Boca arriba, brazos al techo y rodillas a 90°.', 'Estira brazo y pierna contrarios sin despegar la zona lumbar.', 'Alterna lados despacio.'],
);

// ------------------------------------------------------------ estiramientos

const _quadStretch = WarmupMove(
  id: 'est_cuadriceps',
  name: 'Estiramiento de cuádriceps',
  seconds: 30,
  perSide: true,
  region: BodyRegion.lower,
  steps: ['Túmbate de lado y apoya la cabeza en el brazo.', 'Con la mano de arriba, lleva el talón hacia el glúteo.', 'Rodillas juntas y cadera adelante.'],
);
const _hamStretch = WarmupMove(
  id: 'est_isquios',
  name: 'Estiramiento de isquiotibiales',
  seconds: 40,
  region: BodyRegion.lower,
  steps: ['Sentada, una pierna estirada y la otra doblada hacia dentro.', 'Inclínate hacia la pierna estirada con la espalda larga.', 'Llega hasta notar tensión, sin rebotes.'],
);
const _figure4 = WarmupMove(
  id: 'est_gluteo',
  name: 'Glúteo en "figura 4"',
  seconds: 30,
  perSide: true,
  region: BodyRegion.lower,
  steps: ['Boca arriba, cruza un tobillo sobre la rodilla contraria.', 'Acerca la pierna de apoyo hacia el pecho.', 'Respira lento.'],
);
const _butterfly = WarmupMove(
  id: 'est_mariposa',
  name: 'Mariposa (aductores)',
  seconds: 40,
  region: BodyRegion.lower,
  steps: ['Sentada, junta las plantas de los pies.', 'Deja caer las rodillas a los lados.', 'Espalda recta; puedes inclinarte un poco.'],
);
const _calfStretch = WarmupMove(
  id: 'est_gemelo',
  name: 'Gemelo en la pared',
  seconds: 30,
  perSide: true,
  region: BodyRegion.lower,
  steps: ['Manos en la pared, una pierna atrás estirada.', 'Talón de atrás pegado al suelo.', 'Lleva la cadera hacia la pared.'],
);
const _chestStretch = WarmupMove(
  id: 'est_pecho',
  name: 'Apertura de pecho',
  seconds: 30,
  region: BodyRegion.upper,
  steps: ['De pie, manos en la parte baja de la espalda.', 'Lleva los codos hacia atrás y abre el pecho.', 'Hombros abajo, respira lento.'],
);
const _shoulderStretch = WarmupMove(
  id: 'est_hombro',
  name: 'Hombro cruzado',
  seconds: 30,
  perSide: true,
  region: BodyRegion.upper,
  steps: ['Cruza un brazo por delante del pecho.', 'Con el otro brazo, acércalo suavemente.', 'Hombros abajo, lejos de las orejas.'],
);
const _tricepsStretch = WarmupMove(
  id: 'est_triceps',
  name: 'Tríceps tras la cabeza',
  seconds: 30,
  perSide: true,
  region: BodyRegion.upper,
  steps: ['Lleva una mano a la espalda por encima de la cabeza.', 'Con la otra mano, empuja suave el codo.'],
);
const _childPose = WarmupMove(
  id: 'est_nino',
  name: 'Postura del niño',
  seconds: 40,
  region: BodyRegion.core,
  steps: ['De rodillas, siéntate sobre los talones.', 'Inclínate adelante y apoya la frente, con los brazos estirados o junto al cuerpo.', 'Respira hacia la espalda.'],
);
const _cobra = WarmupMove(
  id: 'est_cobra',
  name: 'Cobra suave',
  seconds: 30,
  region: BodyRegion.core,
  steps: ['Boca abajo, manos junto al pecho.', 'Eleva el pecho sin despegar la cadera.', 'Solo hasta donde esté cómodo para tu espalda.'],
);
const _breathing = WarmupMove(
  id: 'respiracion',
  name: 'Respiración para terminar',
  seconds: 40,
  region: BodyRegion.general,
  steps: ['Tumbada o sentada, una mano en el abdomen.', 'Inhala en 4 tiempos, exhala en 6.', '¡Buen trabajo hoy! 💜'],
);

const _lower = {
  MuscleGroup.gluteos,
  MuscleGroup.cuadriceps,
  MuscleGroup.isquiotibiales,
  MuscleGroup.aductores,
  MuscleGroup.abductores,
  MuscleGroup.gemelos,
};
const _upper = {MuscleGroup.pecho, MuscleGroup.espalda, MuscleGroup.hombros, MuscleGroup.biceps, MuscleGroup.triceps};
const _core = {MuscleGroup.abdomen, MuscleGroup.core};

/// Zonas que se trabajan (cardio cuenta como piernas).
Set<BodyRegion> regionsOf(Iterable<MuscleGroup> muscles) => {
      for (final m in muscles)
        if (_lower.contains(m) || m == MuscleGroup.cardio)
          BodyRegion.lower
        else if (_upper.contains(m))
          BodyRegion.upper
        else if (_core.contains(m))
          BodyRegion.core,
    };

/// Calentamiento de unos 5 minutos: general + movilidad y activación de lo que se va a entrenar.
List<WarmupMove> warmupFor(Iterable<MuscleGroup> muscles) {
  final r = regionsOf(muscles);
  final lower = r.contains(BodyRegion.lower) || r.isEmpty;
  final upper = r.contains(BodyRegion.upper);
  final core = r.contains(BodyRegion.core);
  return [
    _march,
    _jacks,
    _hips,
    if (upper || !lower) _armCircles,
    if (upper) ...[_hugs, _wallPush],
    if (lower) ...[_legSwings, _airSquat, _bridge],
    if (core && !(upper && lower)) _catCow,
    if (core && !upper && !lower) _deadBug,
  ];
}

/// Estiramientos de unos 5 minutos de lo que se trabajó, y respiración al final.
List<WarmupMove> cooldownFor(Iterable<MuscleGroup> muscles) {
  final set = muscles.toSet();
  final r = regionsOf(set);
  final lower = r.contains(BodyRegion.lower) || r.isEmpty;
  final upper = r.contains(BodyRegion.upper);
  final both = lower && upper;
  final moves = <WarmupMove>[
    if (lower) ...[
      _quadStretch,
      _hamStretch,
      _figure4,
      if (!both && (set.contains(MuscleGroup.aductores) || set.contains(MuscleGroup.gluteos))) _butterfly,
      if (!both && (set.contains(MuscleGroup.gemelos) || set.contains(MuscleGroup.cardio))) _calfStretch,
    ],
    if (upper) ...[
      _chestStretch,
      _shoulderStretch,
      if (!both || set.contains(MuscleGroup.triceps)) _tricepsStretch,
    ],
    if (r.contains(BodyRegion.core)) _cobra,
    _childPose,
    _breathing,
  ];
  return moves;
}

int totalSeconds(List<WarmupMove> moves) => moves.fold(0, (a, m) => a + m.totalSeconds);

/// Un paso del temporizador: un movimiento, o un lado de un movimiento por lado.
class PhaseStep {
  const PhaseStep(this.move, {this.side});
  final WarmupMove move;

  /// null, 'Lado derecho' o 'Lado izquierdo'.
  final String? side;
  int get seconds => move.seconds;
}

List<PhaseStep> phaseSteps(List<WarmupMove> moves) => [
      for (final m in moves)
        if (m.perSide) ...[
          PhaseStep(m, side: 'Lado derecho'),
          PhaseStep(m, side: 'Lado izquierdo'),
        ] else
          PhaseStep(m),
    ];
