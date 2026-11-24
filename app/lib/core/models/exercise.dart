/// Biblioteca de ejercicios: independiente de las rutinas.
library;

enum MuscleGroup {
  pecho('Pecho'),
  espalda('Espalda'),
  hombros('Hombros'),
  biceps('Bíceps'),
  triceps('Tríceps'),
  abdomen('Abdomen'),
  gluteos('Glúteos'),
  cuadriceps('Cuádriceps'),
  isquiotibiales('Isquiotibiales'),
  aductores('Aductores'),
  abductores('Abductores'),
  gemelos('Gemelos'),
  core('Core'),
  cardio('Cardio');

  const MuscleGroup(this.label);
  final String label;
}

enum Difficulty {
  principiante('Principiante'),
  intermedio('Intermedio'),
  avanzado('Avanzado');

  const Difficulty(this.label);
  final String label;
}

enum Equipment {
  mancuernas('Mancuernas'),
  banco('Banco'),
  pesoCorporal('Peso corporal'),
  bicicleta('Bicicleta estática'),
  banda('Banda elástica'),
  esterilla('Esterilla'),
  cuerda('Cuerda para saltar'),
  saco('Saco de boxeo'),
  guantes('Guantes y vendas'),
  maquinaCardio('Máquina de cardio');

  const Equipment(this.label);
  final String label;
}

/// Formato del recurso visual. La lógica de entrenamiento nunca depende de esto:
/// solo el widget `ExerciseMediaView` sabe cómo pintar cada tipo.
enum MediaKind {
  /// Una sola imagen que ya muestra posición inicial → final.
  combinedImage,

  /// Dos imágenes separadas (inicial y final); se anima la transición.
  imagePair,

  /// Una sola posición que se mantiene (planchas, isométricos).
  holdImage,

  /// Ilustración dibujada en código (src y endSrc = `figure:postura`); se anima entre las dos.
  figure,
  gif,
  video,
  none,
}

class ExerciseMedia {
  const ExerciseMedia({required this.kind, this.src, this.endSrc, this.alt = ''});

  const ExerciseMedia.none() : this(kind: MediaKind.none);

  final MediaKind kind;

  /// Ruta del recurso (asset o archivo local). En `imagePair` es la posición inicial.
  final String? src;

  /// Solo en `imagePair`: posición final.
  final String? endSrc;
  final String alt;

  Map<String, dynamic> toJson() => {'kind': kind.name, 'src': src, 'endSrc': endSrc, 'alt': alt};

  factory ExerciseMedia.fromJson(Map<String, dynamic> j) => ExerciseMedia(
        kind: MediaKind.values.byName(j['kind'] as String),
        src: j['src'] as String?,
        endSrc: j['endSrc'] as String?,
        alt: (j['alt'] as String?) ?? '',
      );
}

enum TargetType { reps, time }

/// Objetivo de una serie: repeticiones (12, 10-12) o tiempo (30 s, 25-30 min).
class SetTarget {
  const SetTarget.reps(this.min, {this.max, this.perSide = false}) : type = TargetType.reps;

  const SetTarget.seconds(this.min, {this.max, this.perSide = false}) : type = TargetType.time;

  const SetTarget._(this.type, this.min, this.max, this.perSide);

  final TargetType type;

  /// Repeticiones o segundos.
  final int min;
  final int? max;
  final bool perSide;

  bool get isTime => type == TargetType.time;

  /// Valor que se usa para el cronómetro en ejercicios por tiempo.
  int get timerSeconds => min;

  String get label {
    final side = perSide ? (isTime ? ' por lado' : ' por pierna') : '';
    if (!isTime) {
      final range = (max != null && max != min) ? '$min-$max' : '$min';
      return '$range reps$side';
    }
    String fmt(int s) => s >= 60 && s % 60 == 0 ? '${s ~/ 60}' : '$s';
    final unit = min >= 60 && min % 60 == 0 ? 'min' : 's';
    final range = (max != null && max != min) ? '${fmt(min)}-${fmt(max!)}' : fmt(min);
    return '$range $unit$side';
  }

  /// Texto corto para la tarjeta grande ("12", "10-12", "30 s").
  String get shortValue {
    if (!isTime) return (max != null && max != min) ? '$min-$max' : '$min';
    return label.replaceAll(' por lado', '');
  }

  String get shortUnit => isTime ? 'Tiempo' : (perSide ? 'Reps / pierna' : 'Repeticiones');

  SetTarget copyWith({TargetType? type, int? min, int? max, bool clearMax = false, bool? perSide}) =>
      SetTarget._(type ?? this.type, min ?? this.min, clearMax ? null : (max ?? this.max), perSide ?? this.perSide);

  Map<String, dynamic> toJson() => {'type': type.name, 'min': min, 'max': max, 'perSide': perSide};

  factory SetTarget.fromJson(Map<String, dynamic> j) => SetTarget._(
        TargetType.values.byName(j['type'] as String),
        j['min'] as int,
        j['max'] as int?,
        (j['perSide'] as bool?) ?? false,
      );
}

class Exercise {
  const Exercise({
    required this.id,
    required this.name,
    required this.primaryMuscle,
    this.secondaryMuscles = const [],
    required this.description,
    this.instructions = const [],
    this.commonMistakes = const [],
    this.equipment = const [],
    this.difficulty = Difficulty.principiante,
    this.startPosition = '',
    this.endPosition = '',
    this.media = const ExerciseMedia.none(),
    required this.suggestedTarget,
    this.custom = false,
  });

  final String id;
  final String name;
  final MuscleGroup primaryMuscle;
  final List<MuscleGroup> secondaryMuscles;
  final String description;
  final List<String> instructions;
  final List<String> commonMistakes;
  final List<Equipment> equipment;
  final Difficulty difficulty;
  final String startPosition;
  final String endPosition;
  final ExerciseMedia media;
  final SetTarget suggestedTarget;

  /// true si lo creó la usuaria.
  final bool custom;

  Exercise copyWith({
    String? name,
    MuscleGroup? primaryMuscle,
    List<MuscleGroup>? secondaryMuscles,
    String? description,
    List<String>? instructions,
    List<String>? commonMistakes,
    List<Equipment>? equipment,
    Difficulty? difficulty,
    String? startPosition,
    String? endPosition,
    ExerciseMedia? media,
    SetTarget? suggestedTarget,
  }) =>
      Exercise(
        id: id,
        name: name ?? this.name,
        primaryMuscle: primaryMuscle ?? this.primaryMuscle,
        secondaryMuscles: secondaryMuscles ?? this.secondaryMuscles,
        description: description ?? this.description,
        instructions: instructions ?? this.instructions,
        commonMistakes: commonMistakes ?? this.commonMistakes,
        equipment: equipment ?? this.equipment,
        difficulty: difficulty ?? this.difficulty,
        startPosition: startPosition ?? this.startPosition,
        endPosition: endPosition ?? this.endPosition,
        media: media ?? this.media,
        suggestedTarget: suggestedTarget ?? this.suggestedTarget,
        custom: custom,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'primaryMuscle': primaryMuscle.name,
        'secondaryMuscles': secondaryMuscles.map((m) => m.name).toList(),
        'description': description,
        'instructions': instructions,
        'commonMistakes': commonMistakes,
        'equipment': equipment.map((e) => e.name).toList(),
        'difficulty': difficulty.name,
        'startPosition': startPosition,
        'endPosition': endPosition,
        'media': media.toJson(),
        'suggestedTarget': suggestedTarget.toJson(),
        'custom': custom,
      };

  factory Exercise.fromJson(Map<String, dynamic> j) => Exercise(
        id: j['id'] as String,
        name: j['name'] as String,
        primaryMuscle: MuscleGroup.values.byName(j['primaryMuscle'] as String),
        secondaryMuscles: [for (final m in j['secondaryMuscles'] as List) MuscleGroup.values.byName(m as String)],
        description: j['description'] as String,
        instructions: List<String>.from(j['instructions'] as List),
        commonMistakes: List<String>.from(j['commonMistakes'] as List),
        equipment: [for (final e in j['equipment'] as List) Equipment.values.byName(e as String)],
        difficulty: Difficulty.values.byName(j['difficulty'] as String),
        startPosition: j['startPosition'] as String,
        endPosition: j['endPosition'] as String,
        media: ExerciseMedia.fromJson(j['media'] as Map<String, dynamic>),
        suggestedTarget: SetTarget.fromJson(j['suggestedTarget'] as Map<String, dynamic>),
        custom: (j['custom'] as bool?) ?? false,
      );
}
