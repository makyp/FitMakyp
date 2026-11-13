import 'body.dart';

enum GoalType {
  weight('Llegar a un peso', 'kg'),
  measure('Llegar a una medida', 'cm'),
  streak('Días de entreno seguidos', 'días'),
  workoutsMonth('Entrenamientos este mes', 'entrenos'),
  checkins('Registros diarios este mes', 'días'),
  waterDays('Días cumpliendo el agua este mes', 'días');

  const GoalType(this.label, this.unit);
  final String label;
  final String unit;
}

class Goal {
  const Goal({
    required this.id,
    required this.type,
    required this.target,
    this.measure,
    this.startValue,
    required this.createdAt,
    this.completedAt,
  });

  final String id;
  final GoalType type;
  final double target;

  /// Solo para [GoalType.measure].
  final Measure? measure;

  /// Valor al crear la meta (peso o medida): sirve para calcular el avance en ambos sentidos.
  final double? startValue;
  final DateTime createdAt;
  final DateTime? completedAt;

  bool get isCompleted => completedAt != null;

  String get title => switch (type) {
        GoalType.weight => 'Llegar a ${_fmt(target)} kg',
        GoalType.measure => '${measure?.label ?? 'Medida'}: ${_fmt(target)} cm',
        GoalType.streak => '${target.round()} ${target.round() == 1 ? 'día' : 'días'} de entreno seguidos',
        GoalType.workoutsMonth => '${target.round()} ${target.round() == 1 ? 'entrenamiento' : 'entrenamientos'} este mes',
        GoalType.checkins => '${target.round()} ${target.round() == 1 ? 'registro diario' : 'registros diarios'} este mes',
        GoalType.waterDays => '${target.round()} ${target.round() == 1 ? 'día' : 'días'} cumpliendo el agua este mes',
      };

  Goal complete(DateTime at) => Goal(
        id: id,
        type: type,
        target: target,
        measure: measure,
        startValue: startValue,
        createdAt: createdAt,
        completedAt: at,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'target': target,
        'measure': measure?.name,
        'startValue': startValue,
        'createdAt': createdAt.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
      };

  factory Goal.fromJson(Map<String, dynamic> j) => Goal(
        id: j['id'] as String,
        type: GoalType.values.byName(j['type'] as String),
        target: (j['target'] as num).toDouble(),
        measure: j['measure'] == null ? null : Measure.values.byName(j['measure'] as String),
        startValue: (j['startValue'] as num?)?.toDouble(),
        createdAt: DateTime.parse(j['createdAt'] as String),
        completedAt: j['completedAt'] == null ? null : DateTime.parse(j['completedAt'] as String),
      );
}

String _fmt(double v) => v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);
