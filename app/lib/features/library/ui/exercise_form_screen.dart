import 'package:flutter/material.dart';

import '../../../app_scope.dart';
import '../../../core/models/exercise.dart';
import '../../../core/utils/ids.dart';

/// Crear un ejercicio propio o editar uno existente.
class ExerciseFormScreen extends StatefulWidget {
  const ExerciseFormScreen({super.key, this.initial});
  final Exercise? initial;

  @override
  State<ExerciseFormScreen> createState() => _ExerciseFormScreenState();
}

class _ExerciseFormScreenState extends State<ExerciseFormScreen> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initial?.name);
  late final _description = TextEditingController(text: widget.initial?.description);
  late final _instructions = TextEditingController(text: widget.initial?.instructions.join('\n'));
  late final _mistakes = TextEditingController(text: widget.initial?.commonMistakes.join('\n'));
  late final _start = TextEditingController(text: widget.initial?.startPosition);
  late final _end = TextEditingController(text: widget.initial?.endPosition);
  late MuscleGroup _muscle = widget.initial?.primaryMuscle ?? MuscleGroup.gluteos;
  late Difficulty _difficulty = widget.initial?.difficulty ?? Difficulty.principiante;
  late bool _isTime = widget.initial?.suggestedTarget.isTime ?? false;
  late final _amount = TextEditingController(text: '${widget.initial?.suggestedTarget.min ?? 12}');

  @override
  void dispose() {
    for (final c in [_name, _description, _instructions, _mistakes, _start, _end, _amount]) {
      c.dispose();
    }
    super.dispose();
  }

  List<String> _lines(TextEditingController c) =>
      c.text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final amount = int.parse(_amount.text);
    final base = widget.initial;
    final target = _isTime ? SetTarget.seconds(amount) : SetTarget.reps(amount);
    final exercise = base == null
        ? Exercise(
            id: newId('ex'),
            name: _name.text.trim(),
            primaryMuscle: _muscle,
            description: _description.text.trim(),
            instructions: _lines(_instructions),
            commonMistakes: _lines(_mistakes),
            difficulty: _difficulty,
            startPosition: _start.text.trim(),
            endPosition: _end.text.trim(),
            suggestedTarget: target,
            custom: true,
          )
        : base.copyWith(
            name: _name.text.trim(),
            primaryMuscle: _muscle,
            description: _description.text.trim(),
            instructions: _lines(_instructions),
            commonMistakes: _lines(_mistakes),
            difficulty: _difficulty,
            startPosition: _start.text.trim(),
            endPosition: _end.text.trim(),
            suggestedTarget: base.suggestedTarget.type == target.type && base.suggestedTarget.min == amount
                ? base.suggestedTarget
                : target,
          );
    await AppScope.of(context).library.upsert(exercise);
    if (mounted) Navigator.pop(context, exercise);
  }

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 14);
    return Scaffold(
      appBar: AppBar(title: Text(widget.initial == null ? 'Nuevo ejercicio' : 'Editar ejercicio')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
          children: [
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Nombre *'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Escribe un nombre' : null,
            ),
            gap,
            DropdownButtonFormField<MuscleGroup>(
              initialValue: _muscle,
              decoration: const InputDecoration(labelText: 'Grupo muscular principal'),
              items: [for (final m in MuscleGroup.values) DropdownMenuItem(value: m, child: Text(m.label))],
              onChanged: (v) => setState(() => _muscle = v!),
            ),
            gap,
            DropdownButtonFormField<Difficulty>(
              initialValue: _difficulty,
              decoration: const InputDecoration(labelText: 'Dificultad'),
              items: [for (final d in Difficulty.values) DropdownMenuItem(value: d, child: Text(d.label))],
              onChanged: (v) => setState(() => _difficulty = v!),
            ),
            gap,
            Row(
              children: [
                Expanded(
                  child: SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: false, label: Text('Reps')),
                      ButtonSegment(value: true, label: Text('Segundos')),
                    ],
                    selected: {_isTime},
                    onSelectionChanged: (v) => setState(() => _isTime = v.first),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 100,
                  child: TextFormField(
                    controller: _amount,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: _isTime ? 'Segundos' : 'Reps'),
                    validator: (v) => (int.tryParse(v ?? '') ?? 0) > 0 ? null : 'Número',
                  ),
                ),
              ],
            ),
            gap,
            TextFormField(
              controller: _description,
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Descripción'),
            ),
            gap,
            TextFormField(controller: _start, decoration: const InputDecoration(labelText: 'Posición inicial')),
            gap,
            TextFormField(controller: _end, decoration: const InputDecoration(labelText: 'Posición final')),
            gap,
            TextFormField(
              controller: _instructions,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Técnica (un paso por línea)', alignLabelWithHint: true),
            ),
            gap,
            TextFormField(
              controller: _mistakes,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Errores frecuentes (uno por línea)', alignLabelWithHint: true),
            ),
            const SizedBox(height: 24),
            FilledButton(onPressed: _save, child: const Text('GUARDAR')),
          ],
        ),
      ),
    );
  }
}
