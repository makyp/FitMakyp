import 'package:flutter/material.dart';

import '../../../core/models/exercise.dart';
import '../../../core/models/plan.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';

class WorkoutExerciseEdit {
  const WorkoutExerciseEdit.save(WorkoutExercise this.value) : delete = false;
  const WorkoutExerciseEdit.remove()
      : value = null,
        delete = true;
  final WorkoutExercise? value;
  final bool delete;
}

/// Hoja inferior para editar series, objetivo y descanso de un ejercicio de la rutina.
Future<WorkoutExerciseEdit?> showWorkoutExerciseSheet(
  BuildContext context, {
  required WorkoutExercise initial,
  required String exerciseName,
  required int defaultRest,
}) =>
    showModalBottomSheet<WorkoutExerciseEdit>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: FmColors.surface,
      builder: (_) => _Sheet(initial: initial, name: exerciseName, defaultRest: defaultRest),
    );

class _Sheet extends StatefulWidget {
  const _Sheet({required this.initial, required this.name, required this.defaultRest});
  final WorkoutExercise initial;
  final String name;
  final int defaultRest;

  @override
  State<_Sheet> createState() => _SheetState();
}

class _SheetState extends State<_Sheet> {
  late int _sets = widget.initial.sets;
  late SetTarget _target = widget.initial.target;
  late bool _customRest = widget.initial.restSeconds != null;
  late int _rest = widget.initial.restSeconds ?? widget.defaultRest;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final isTime = _target.isTime;
    // En ejercicios por tiempo se edita en segundos o minutos según el valor.
    final useMinutes = isTime && _target.min >= 60;
    final unit = isTime ? (useMinutes ? 'min' : 's') : 'reps';
    final factor = useMinutes ? 60 : 1;
    final step = isTime ? (useMinutes ? 60 : 5) : 1;
    final maxValue = _target.max ?? _target.min;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.name, style: t.titleLarge),
            const SizedBox(height: 16),
            _Stepper(label: 'Series', value: '$_sets', onMinus: _sets > 1 ? () => setState(() => _sets--) : null,
                onPlus: () => setState(() => _sets++)),
            const SizedBox(height: 12),
            SegmentedButton<TargetType>(
              segments: const [
                ButtonSegment(value: TargetType.reps, label: Text('Repeticiones')),
                ButtonSegment(value: TargetType.time, label: Text('Tiempo')),
              ],
              selected: {_target.type},
              onSelectionChanged: (v) => setState(() {
                _target = v.first == TargetType.reps
                    ? SetTarget.reps(12, perSide: _target.perSide)
                    : SetTarget.seconds(30, perSide: _target.perSide);
              }),
            ),
            const SizedBox(height: 12),
            _Stepper(
              label: 'Mínimo ($unit)',
              value: '${_target.min ~/ factor}',
              onMinus: _target.min - step >= step
                  ? () => setState(() {
                        final min = _target.min - step;
                        _target = _target.copyWith(min: min);
                      })
                  : null,
              onPlus: () => setState(() {
                final min = _target.min + step;
                _target = _target.copyWith(min: min, max: maxValue < min ? min : maxValue);
              }),
            ),
            const SizedBox(height: 12),
            _Stepper(
              label: 'Máximo ($unit)',
              hint: 'Igual al mínimo = valor fijo',
              value: '${maxValue ~/ factor}',
              onMinus: maxValue - step >= _target.min
                  ? () => setState(() => _target = _target.copyWith(max: maxValue - step))
                  : null,
              onPlus: () => setState(() => _target = _target.copyWith(max: maxValue + step)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(isTime ? 'Por lado' : 'Por pierna / lado'),
              value: _target.perSide,
              onChanged: (v) => setState(() => _target = _target.copyWith(perSide: v)),
            ),
            const Divider(),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Descanso propio'),
              subtitle: Text(_customRest
                  ? 'Este ejercicio usa su propio descanso'
                  : 'Usa el general (${formatClock(Duration(seconds: widget.defaultRest))})'),
              value: _customRest,
              onChanged: (v) => setState(() => _customRest = v),
            ),
            if (_customRest)
              _Stepper(
                label: 'Descanso',
                value: formatClock(Duration(seconds: _rest)),
                onMinus: _rest >= 15 ? () => setState(() => _rest -= 15) : null,
                onPlus: () => setState(() => _rest += 15),
              ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () {
                final target = (_target.max == _target.min) ? _target.copyWith(clearMax: true) : _target;
                Navigator.pop(
                  context,
                  WorkoutExerciseEdit.save(widget.initial.copyWith(
                    sets: _sets,
                    target: target,
                    restSeconds: _customRest ? _rest : null,
                    clearRest: !_customRest,
                  )),
                );
              },
              child: const Text('GUARDAR'),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: Colors.red.shade400),
              onPressed: () => Navigator.pop(context, const WorkoutExerciseEdit.remove()),
              icon: const Icon(Icons.delete_outline_rounded),
              label: const Text('Quitar de este día'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({required this.label, required this.value, this.onMinus, this.onPlus, this.hint});
  final String label;
  final String value;
  final String? hint;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: t.titleSmall),
              if (hint != null) Text(hint!, style: t.bodySmall?.copyWith(color: FmColors.muted)),
            ],
          ),
        ),
        IconButton.filledTonal(onPressed: onMinus, icon: const Icon(Icons.remove_rounded)),
        SizedBox(
          width: 64,
          child: Text(value, textAlign: TextAlign.center, style: t.titleLarge),
        ),
        IconButton.filledTonal(onPressed: onPlus, icon: const Icon(Icons.add_rounded)),
      ],
    );
  }
}
