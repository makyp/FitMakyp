/// Rutina matutina de hipopresivos: todo de pie (como mucho apoyada en la pared).
/// Lógica pura: posturas, niveles y la secuencia de respiración paso a paso.
library;

/// Qué se hace en cada momento de una repetición.
enum BreathPhase {
  prepare('Colócate', 'Colócate en la postura'),
  inhale('Inhala', 'Por la nariz, abriendo las costillas'),
  exhale('Exhala', 'Por la boca, lento y relajado'),
  emptyOut('Saca todo el aire', 'Vacía los pulmones por completo'),
  apnea('Apnea: abre costillas', 'Sin aire: abre las costillas como si inhalaras y el ombligo se va adentro y arriba'),
  release('Suelta e inhala', 'Relaja el abdomen e inhala suave por la nariz'),
  recover('Respira normal', 'Recupera con calma antes de la siguiente');

  const BreathPhase(this.label, this.hint);
  final String label;
  final String hint;

  /// Frase corta para la voz.
  String get spoken => switch (this) {
        BreathPhase.prepare => '',
        BreathPhase.inhale => 'Inhala',
        BreathPhase.exhale => 'Exhala',
        BreathPhase.emptyOut => 'Saca todo el aire',
        BreathPhase.apnea => 'Aguanta sin aire. Abre las costillas y mete el ombligo',
        BreathPhase.release => 'Suelta. Inhala suave',
        BreathPhase.recover => 'Respira normal',
      };
}

enum HypoLevel {
  suave('Suave', 'Para empezar', reps: 2, apnea: 8),
  media('Media', 'Ya los conoces', reps: 3, apnea: 12),
  avanzada('Avanzada', 'Los haces seguido', reps: 3, apnea: 18);

  const HypoLevel(this.label, this.description, {required this.reps, required this.apnea});
  final String label;
  final String description;

  /// Repeticiones (apneas) por postura.
  final int reps;

  /// Segundos de apnea.
  final int apnea;
}

/// Ángulos de la figura animada (vista de perfil, grados).
class PoseSpec {
  const PoseSpec({
    this.lean = 0,
    this.knees = 10,
    this.shoulder = 15,
    this.elbow = 10,
    this.handsOnThighs = false,
    this.wall = false,
  });

  /// Inclinación del tronco hacia delante.
  final double lean;

  /// Flexión de rodillas.
  final double knees;

  /// Brazo respecto al tronco (0 = colgando, 90 = al frente, 180 = arriba).
  final double shoulder;

  /// Flexión del codo.
  final double elbow;
  final bool handsOnThighs;
  final bool wall;
}

class HypoPosture {
  const HypoPosture({required this.id, required this.name, required this.tips, required this.pose});
  final String id;
  final String name;
  final List<String> tips;
  final PoseSpec pose;
}

/// Claves de todas las posturas (se repiten en cada una).
const hypoBasics = [
  'Crece: como si un hilo tirara de tu coronilla hacia el techo.',
  'Barbilla un poco hacia dentro, nuca larga.',
  'Rodillas suaves y el peso un poco hacia la punta de los pies.',
  'Empuja los codos hacia fuera para separar los hombros de las orejas.',
];

const hypoPostures = [
  HypoPosture(
    id: 'base',
    name: 'De pie, brazos a los lados',
    tips: [
      'Pies al ancho de caderas, rodillas suaves.',
      'Brazos a los lados, un poco separados del cuerpo.',
      'Muñecas flexionadas, palmas mirando al suelo.',
    ],
    pose: PoseSpec(lean: 4, knees: 10, shoulder: 18, elbow: 8),
  ),
  HypoPosture(
    id: 'frente',
    name: 'Brazos al frente',
    tips: [
      'Brazos al frente a la altura del pecho, codos hacia fuera.',
      'Las puntas de los dedos se miran sin tocarse.',
      'Peso hacia la punta de los pies sin despegar los talones.',
    ],
    pose: PoseSpec(lean: 6, knees: 12, shoulder: 78, elbow: 55),
  ),
  HypoPosture(
    id: 'inclinada',
    name: 'Inclinada, manos en los muslos',
    tips: [
      'Flexiona más las rodillas e inclina el tronco adelante con la espalda recta.',
      'Apoya las manos en los muslos, dedos hacia dentro.',
      'Codos hacia fuera y la cabeza alineada con la espalda.',
    ],
    pose: PoseSpec(lean: 32, knees: 30, handsOnThighs: true),
  ),
  HypoPosture(
    id: 'arriba',
    name: 'Brazos en alto',
    tips: [
      'Sube los brazos por encima de la cabeza, codos un poco flexionados.',
      'Empuja las manos hacia el techo sin subir los hombros.',
      'Si te cansas los hombros, bájalos al frente.',
    ],
    pose: PoseSpec(lean: 3, knees: 10, shoulder: 176, elbow: 2),
  ),
  HypoPosture(
    id: 'pared',
    name: 'Espalda contra la pared',
    tips: [
      'Talones a un pie de la pared; glúteos, espalda y cabeza apoyados.',
      'Rodillas suaves, brazos al frente a la altura del pecho.',
      'Despega un poco la zona lumbar de la pared al hacer la apnea.',
    ],
    pose: PoseSpec(lean: 0, knees: 18, shoulder: 78, elbow: 55, wall: true),
  ),
];

/// Un tramo de la guía con su duración.
class HypoStep {
  const HypoStep({
    required this.posture,
    required this.postureIndex,
    required this.phase,
    required this.seconds,
    this.rep = 0,
    this.breath = 0,
  });

  final HypoPosture posture;
  final int postureIndex;
  final BreathPhase phase;
  final int seconds;

  /// Repetición (1…reps); 0 al colocarse.
  final int rep;

  /// Respiración de preparación (1…3) en inhalar/exhalar.
  final int breath;
}

const _inhaleS = 3;
const _exhaleS = 4;
const _emptyS = 4;
const _releaseS = 4;
const _recoverS = 8;
const _prepareS = 10;
const _breaths = 3;

List<HypoStep> buildHypoSteps(HypoLevel level, [List<HypoPosture> postures = hypoPostures]) => [
      for (final (pi, p) in postures.indexed) ...[
        HypoStep(posture: p, postureIndex: pi, phase: BreathPhase.prepare, seconds: _prepareS),
        for (var r = 1; r <= level.reps; r++) ...[
          for (var b = 1; b <= _breaths; b++) ...[
            HypoStep(posture: p, postureIndex: pi, phase: BreathPhase.inhale, seconds: _inhaleS, rep: r, breath: b),
            HypoStep(posture: p, postureIndex: pi, phase: BreathPhase.exhale, seconds: _exhaleS, rep: r, breath: b),
          ],
          HypoStep(posture: p, postureIndex: pi, phase: BreathPhase.emptyOut, seconds: _emptyS, rep: r),
          HypoStep(posture: p, postureIndex: pi, phase: BreathPhase.apnea, seconds: level.apnea, rep: r),
          HypoStep(posture: p, postureIndex: pi, phase: BreathPhase.release, seconds: _releaseS, rep: r),
          HypoStep(posture: p, postureIndex: pi, phase: BreathPhase.recover, seconds: _recoverS, rep: r),
        ],
      ],
    ];

int hypoTotalSeconds(HypoLevel level) => buildHypoSteps(level).fold(0, (a, s) => a + s.seconds);

/// Forma del cuerpo en la animación: pecho, abdomen (+ fuera, − dentro) y costillas abiertas.
class BreathShape {
  const BreathShape(this.chest, this.belly, this.ribs);
  final double chest;
  final double belly;
  final double ribs;

  static const rest = BreathShape(0, 0, 0);

  BreathShape lerpTo(BreathShape o, double t) => BreathShape(
        chest + (o.chest - chest) * t,
        belly + (o.belly - belly) * t,
        ribs + (o.ribs - ribs) * t,
      );
}

const _afterInhale = BreathShape(0.6, 0.7, 0.2);
const _afterExhale = BreathShape(0, -0.1, 0);
const _empty = BreathShape(-0.1, -0.5, 0);
const _hollow = BreathShape(0.7, -1.5, 1);
const _released = BreathShape(0.4, 0.3, 0.1);

double _ease(double t) => t < 0.5 ? 2 * t * t : 1 - 2 * (1 - t) * (1 - t);

/// Forma del cuerpo [elapsed] segundos dentro de un paso.
BreathShape breathShapeAt(BreathPhase phase, double elapsed, int seconds) {
  final t = seconds <= 0 ? 1.0 : (elapsed / seconds).clamp(0.0, 1.0);
  return switch (phase) {
    BreathPhase.prepare => BreathShape.rest,
    BreathPhase.inhale => _afterExhale.lerpTo(_afterInhale, _ease(t)),
    BreathPhase.exhale => _afterInhale.lerpTo(_afterExhale, _ease(t)),
    BreathPhase.emptyOut => _afterExhale.lerpTo(_empty, _ease(t)),
    // El abdomen se mete en unos 2 s y se mantiene.
    BreathPhase.apnea => _empty.lerpTo(_hollow, _ease((elapsed / 2).clamp(0.0, 1.0))),
    BreathPhase.release => _hollow.lerpTo(_released, _ease(t)),
    BreathPhase.recover => _released.lerpTo(BreathShape.rest, _ease(t)),
  };
}
