import 'package:flutter/material.dart';

import '../../../app_scope.dart';
import '../../../core/models/exercise.dart';
import '../../../core/models/plan.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/ids.dart';

/// Elegir a qué día de la rutina activa se agrega un ejercicio (3 series con su objetivo sugerido).
Future<void> showAddToDaySheet(BuildContext context, Exercise ex) async {
  final scope = AppScope.of(context);
  final days = [...scope.plans.active.days]..sort((a, b) => a.weekday.compareTo(b.weekday));
  final day = await showModalBottomSheet<WorkoutDay>(
    context: context,
    showDragHandle: true,
    backgroundColor: FmColors.surface,
    builder: (ctx) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Text('Agregar "${ex.name}" a…', style: Theme.of(ctx).textTheme.titleMedium),
          ),
          for (final d in days)
            ListTile(
              leading: CircleAvatar(
                backgroundColor: d.isTraining ? FmColors.lavender : FmColors.warmWhite,
                foregroundColor: FmColors.primary,
                child: Text(d.weekdayName.substring(0, 2)),
              ),
              title: Text(d.title),
              subtitle: Text(d.isTraining
                  ? '${d.weekdayName} · ${d.activeExercises.length} ejercicios'
                  : '${d.weekdayName} · ahora es descanso'),
              trailing: d.exercises.any((e) => e.exerciseId == ex.id)
                  ? Icon(Icons.check_rounded, color: FmColors.primary)
                  : null,
              onTap: () => Navigator.pop(ctx, d),
            ),
        ],
      ),
    ),
  );
  if (day == null) return;
  await scope.plans.addExerciseToDay(
    day.id,
    WorkoutExercise(id: newId('we'), exerciseId: ex.id, sets: 3, target: ex.suggestedTarget),
  );
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${ex.name} agregado al ${day.weekdayName.toLowerCase()} (3 series).')),
    );
  }
}
