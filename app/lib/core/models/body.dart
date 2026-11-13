/// Seguimiento corporal: peso, medidas, fotos y registro diario.
library;

enum Measure {
  peso('Peso', 'kg'),
  cintura('Cintura', 'cm'),
  abdomen('Abdomen', 'cm'),
  cadera('Cadera', 'cm'),
  gluteos('Glúteos', 'cm'),
  musloDer('Muslo derecho', 'cm'),
  musloIzq('Muslo izquierdo', 'cm'),
  brazoDer('Brazo derecho', 'cm'),
  brazoIzq('Brazo izquierdo', 'cm'),
  pecho('Pecho', 'cm');

  const Measure(this.label, this.unit);
  final String label;
  final String unit;
}

enum PhotoAngle {
  frontal('Frontal'),
  lateral('Lateral'),
  posterior('Posterior');

  const PhotoAngle(this.label);
  final String label;
}

/// Un registro de progreso (cada 15 días o cuando quieras). Todo es opcional.
class ProgressRecord {
  const ProgressRecord({
    required this.id,
    required this.date,
    this.values = const {},
    this.photos = const {},
    this.note = '',
  });

  final String id;
  final DateTime date;
  final Map<Measure, double> values;

  /// Id de la foto guardada en el dispositivo para cada ángulo.
  final Map<PhotoAngle, String> photos;
  final String note;

  bool get hasPhotos => photos.isNotEmpty;

  ProgressRecord copyWith({DateTime? date, Map<Measure, double>? values, Map<PhotoAngle, String>? photos, String? note}) =>
      ProgressRecord(
        id: id,
        date: date ?? this.date,
        values: values ?? this.values,
        photos: photos ?? this.photos,
        note: note ?? this.note,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'values': {for (final e in values.entries) e.key.name: e.value},
        'photos': {for (final e in photos.entries) e.key.name: e.value},
        'note': note,
      };

  factory ProgressRecord.fromJson(Map<String, dynamic> j) => ProgressRecord(
        id: j['id'] as String,
        date: DateTime.parse(j['date'] as String),
        values: {
          for (final e in (j['values'] as Map<String, dynamic>).entries)
            if (Measure.values.any((m) => m.name == e.key)) Measure.values.byName(e.key): (e.value as num).toDouble(),
        },
        photos: {
          for (final e in (j['photos'] as Map<String, dynamic>).entries)
            if (PhotoAngle.values.any((a) => a.name == e.key)) PhotoAngle.values.byName(e.key): e.value as String,
        },
        note: (j['note'] as String?) ?? '',
      );
}

/// Registro diario opcional: cómo te sientes. Escala 1-5.
class DailyCheckin {
  const DailyCheckin({
    required this.date,
    this.mood = 3,
    this.energy = 3,
    this.sleep = 3,
    this.activity = 3,
    this.comment = '',
  });

  /// Solo fecha (sin hora): una entrada por día.
  final DateTime date;
  final int mood;
  final int energy;
  final int sleep;
  final int activity;
  final String comment;

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'mood': mood,
        'energy': energy,
        'sleep': sleep,
        'activity': activity,
        'comment': comment,
      };

  factory DailyCheckin.fromJson(Map<String, dynamic> j) => DailyCheckin(
        date: DateTime.parse(j['date'] as String),
        mood: j['mood'] as int,
        energy: j['energy'] as int,
        sleep: j['sleep'] as int,
        activity: j['activity'] as int,
        comment: (j['comment'] as String?) ?? '',
      );
}

/// Cambio entre dos valores. El porcentaje solo se da si es matemáticamente válido.
class MeasureDelta {
  const MeasureDelta(this.from, this.to);
  final double from;
  final double to;

  double get diff => to - from;
  double? get percent => from == 0 ? null : diff / from * 100;
}
