/// Rutina con IA por "copiar y pegar": arma la pregunta para pegarla en un chat de IA gratuito
/// y lee la respuesta (JSON) para convertirla en una rutina. No hay conexión directa con ninguna IA.
library;

import 'dart:convert';

import '../../../core/models/exercise.dart';
import '../../../core/models/plan.dart';

enum AiGoal {
  tonificar('Tonificar y ganar fuerza'),
  gluteosPiernas('Priorizar glúteos y piernas'),
  fuerza('Ganar fuerza'),
  salud('Salud general y energía'),
  resistencia('Mejorar resistencia (cardio)');

  const AiGoal(this.label);
  final String label;
}

enum AiLevel {
  principiante('Principiante'),
  intermedio('Intermedio'),
  avanzado('Avanzado');

  const AiLevel(this.label);
  final String label;
}

class AiPlanRequest {
  const AiPlanRequest({
    required this.goal,
    required this.weekdays,
    required this.minutes,
    required this.level,
    required this.equipment,
    this.focus = const {},
    this.notes = '',
    this.trainingSummary,
  });

  final AiGoal goal;

  /// Días de entrenamiento (1 = lunes … 7 = domingo).
  final Set<int> weekdays;
  final int minutes;
  final AiLevel level;
  final Set<Equipment> equipment;
  final Set<MuscleGroup> focus;
  final String notes;

  /// Resumen opcional: series por semana de cada músculo en los últimos 30 días.
  final Map<MuscleGroup, double>? trainingSummary;
}

const _dayKeys = ['lunes', 'martes', 'miercoles', 'jueves', 'viernes', 'sabado', 'domingo'];

String _norm(String s) {
  const from = 'áéíóúüñÁÉÍÓÚÜÑ';
  const to = 'aeiouunAEIOUUN';
  final b = StringBuffer();
  for (final c in s.trim().toLowerCase().split('')) {
    final i = from.indexOf(c);
    b.write(i >= 0 ? to[i] : c);
  }
  return b.toString().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
}

/// Ejercicios que se pueden hacer con el equipo elegido.
List<Exercise> availableExercises(List<Exercise> library, Set<Equipment> equipment) => [
      for (final e in library)
        if (e.equipment.every((q) => equipment.contains(q) || q == Equipment.pesoCorporal || q == Equipment.esterilla))
          e,
    ];

/// Texto para pegar en ChatGPT, Gemini o Claude.
String buildAiPrompt(AiPlanRequest r, List<Exercise> library) {
  final days = (r.weekdays.toList()..sort()).map((d) => weekdayNames[d - 1].toLowerCase()).join(', ');
  final exercises = availableExercises(library, r.equipment);
  final b = StringBuffer()
    ..writeln('Actúa como entrenadora personal. Diseña una rutina semanal segura y realista para mí.')
    ..writeln()
    ..writeln('Sobre mí:')
    ..writeln('- Objetivo: ${r.goal.label}')
    ..writeln('- Entreno ${r.weekdays.length} días: $days (el resto son descanso)')
    ..writeln('- Tiempo por sesión: unos ${r.minutes} minutos')
    ..writeln('- Nivel: ${r.level.label}')
    ..writeln('- Equipo disponible: ${r.equipment.isEmpty ? 'solo peso corporal' : r.equipment.map((e) => e.label).join(', ')}');
  if (r.focus.isNotEmpty) b.writeln('- Zonas que quiero priorizar: ${r.focus.map((m) => m.label).join(', ')}');
  final sum = r.trainingSummary;
  if (sum != null && sum.isNotEmpty) {
    final items = sum.entries.toList()..sort((a, c) => c.value.compareTo(a.value));
    b.writeln(
        '- Lo que he entrenado el último mes (series por semana): ${items.map((e) => '${e.key.label} ${e.value.toStringAsFixed(1)}').join(', ')}');
  }
  if (r.notes.trim().isNotEmpty) b.writeln('- Notas o limitaciones: ${r.notes.trim()}');
  b
    ..writeln()
    ..writeln('Reglas:')
    ..writeln('- Usa SOLO ejercicios de esta lista y escribe su id exacto:')
    ..writeln('  id | nombre | músculo principal | equipo');
  for (final e in exercises) {
    b.writeln('  ${e.id} | ${e.name} | ${e.primaryMuscle.label} | '
        '${e.equipment.isEmpty ? 'ninguno' : e.equipment.map((q) => q.label).join(', ')}');
  }
  b
    ..writeln('- Entre 4 y 7 ejercicios por día, que quepan en el tiempo indicado.')
    ..writeln('- Series de 2 a 5. Usa "reps" (por ejemplo "10-12") o "segundos" para planchas, isométricos y cardio.')
    ..writeln('- Descanso entre 30 y 120 segundos.')
    ..writeln('- Reparte bien los músculos durante la semana y deja recuperar cada grupo.')
    ..writeln('- La app añade sola el calentamiento y los estiramientos de cada día: no los incluyas en la lista.')
    ..writeln('- Progresión moderada: nada extremo. No incluyas dietas ni indicaciones médicas.')
    ..writeln()
    ..writeln('Responde ÚNICAMENTE con un bloque JSON con este formato exacto (sin texto antes ni después):')
    ..writeln('{"nombre": "Nombre de la rutina", "dias": [{"dia": "lunes", "titulo": "Glúteos y piernas", '
        '"ejercicios": [{"id": "sentadilla", "series": 3, "reps": "10-12", "descanso": 60}, '
        '{"id": "plancha_frontal", "series": 3, "segundos": 30, "descanso": 45}]}], '
        '"consejos": ["consejo breve"]}');
  return b.toString();
}

class AiPlanResult {
  AiPlanResult(this.plan, this.warnings, this.tips);
  final WorkoutPlan plan;
  final List<String> warnings;
  final List<String> tips;

  int get exerciseCount => plan.days.fold(0, (a, d) => a + d.exercises.length);
}

class AiParseException implements Exception {
  AiParseException(this.message);
  final String message;
  @override
  String toString() => message;
}

int _int(Object? v, int fallback, int lo, int hi) {
  final n = v is num ? v.round() : int.tryParse('${v ?? ''}'.replaceAll(RegExp(r'[^0-9]'), ''));
  return (n ?? fallback).clamp(lo, hi);
}

SetTarget _target(Map<String, dynamic> j, Exercise? ex) {
  final secs = j['segundos'] ?? j['tiempo'] ?? j['seconds'];
  if (secs != null) {
    final s = _int(secs, 30, 5, 3600);
    return SetTarget.seconds(s);
  }
  final reps = j['reps'] ?? j['repeticiones'];
  if (reps == null) return ex?.suggestedTarget ?? const SetTarget.reps(10, max: 12);
  final nums = RegExp(r'\d+').allMatches('$reps').map((m) => int.parse(m.group(0)!).clamp(1, 50)).toList();
  if (nums.isEmpty) return ex?.suggestedTarget ?? const SetTarget.reps(10, max: 12);
  final perSide = '$reps'.contains('lado') || '$reps'.contains('pierna');
  final min = nums.first;
  final max = nums.length > 1 && nums[1] > min ? nums[1] : null;
  return SetTarget.reps(min, max: max, perSide: perSide);
}

/// Lee la respuesta de la IA. Acepta el JSON solo, dentro de ```json … ``` o con texto alrededor.
AiPlanResult parseAiPlan(String text, List<Exercise> library, {required String Function(String) newId, DateTime? now}) {
  if (text.contains('Actúa como entrenadora personal') && text.contains('Responde ÚNICAMENTE')) {
    throw AiParseException('Parece que pegaste la pregunta, no la respuesta. Pégala en la IA y luego copia lo que te responda.');
  }
  final start = text.indexOf('{');
  final end = text.lastIndexOf('}');
  if (start < 0 || end <= start) {
    throw AiParseException('No encontré la rutina en el texto. Copia la respuesta completa de la IA (el bloque que empieza con "{").');
  }
  Object? data;
  try {
    data = jsonDecode(text.substring(start, end + 1));
  } on FormatException {
    throw AiParseException('La respuesta no tiene el formato esperado. Pídele a la IA: "Responde solo con el JSON".');
  }
  if (data is! Map<String, dynamic> || data['dias'] is! List) {
    throw AiParseException('Falta la lista de días ("dias") en la respuesta.');
  }

  final byId = {for (final e in library) e.id: e};
  final byName = {for (final e in library) _norm(e.name): e};
  final warnings = <String>[];
  final days = <int, WorkoutDay>{};

  for (final raw in data['dias'] as List) {
    if (raw is! Map<String, dynamic>) continue;
    final d = raw['dia'];
    int? weekday;
    if (d is num) {
      weekday = d.round();
    } else if (d != null) {
      final k = _norm('$d');
      final i = _dayKeys.indexWhere((x) => k.startsWith(x.substring(0, 3)));
      weekday = i < 0 ? null : i + 1;
    }
    if (weekday == null || weekday < 1 || weekday > 7) {
      warnings.add('Se ignoró un día que no reconocí ("$d").');
      continue;
    }
    if (days.containsKey(weekday)) {
      warnings.add('${weekdayNames[weekday - 1]} aparecía dos veces: se usó el primero.');
      continue;
    }
    final exercises = <WorkoutExercise>[];
    for (final re in (raw['ejercicios'] as List?) ?? const []) {
      if (re is! Map<String, dynamic>) continue;
      final id = '${re['id'] ?? ''}'.trim();
      final ex = byId[id] ?? byName[_norm('${re['nombre'] ?? id}')] ?? byName[_norm(id.replaceAll('_', ' '))];
      if (ex == null) {
        warnings.add('"${re['nombre'] ?? id}" no está en tu biblioteca: no se agregó.');
        continue;
      }
      if (exercises.length >= 10) {
        warnings.add('${weekdayNames[weekday - 1]}: había más de 10 ejercicios, se dejaron 10.');
        break;
      }
      exercises.add(WorkoutExercise(
        id: newId('we'),
        exerciseId: ex.id,
        sets: _int(re['series'], 3, 1, 8),
        target: _target(re, ex),
        restSeconds: re['descanso'] == null ? null : _int(re['descanso'], 60, 0, 300),
      ));
    }
    final title = '${raw['titulo'] ?? ''}'.trim();
    days[weekday] = WorkoutDay(
      id: newId('day'),
      weekday: weekday,
      kind: exercises.isEmpty ? DayKind.rest : DayKind.training,
      title: title.isEmpty ? (exercises.isEmpty ? 'Descanso' : 'Entrenamiento') : title,
      exercises: exercises,
    );
  }

  if (!days.values.any((d) => d.isTraining)) {
    throw AiParseException('La rutina no tiene ejercicios que estén en tu biblioteca.');
  }
  for (var w = 1; w <= 7; w++) {
    days.putIfAbsent(w, () => WorkoutDay(id: newId('day'), weekday: w, kind: DayKind.rest, title: 'Descanso'));
  }
  final t = now ?? DateTime.now();
  final name = '${data['nombre'] ?? ''}'.trim();
  final tips = [for (final x in (data['consejos'] as List?) ?? const []) if ('$x'.trim().isNotEmpty) '$x'.trim()];
  return AiPlanResult(
    WorkoutPlan(
      id: newId('plan'),
      name: name.isEmpty ? 'Rutina con IA' : (name.length > 40 ? name.substring(0, 40) : name),
      days: [for (var w = 1; w <= 7; w++) days[w]!],
      createdAt: t,
      updatedAt: t,
    ),
    warnings,
    tips.take(6).toList(),
  );
}
