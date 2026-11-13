import 'package:flutter/material.dart';

import '../../../app_scope.dart';
import '../../../core/models/plan.dart';
import 'session_screen.dart';

/// Inicia (o retoma) un entrenamiento y abre la pantalla de sesión.
Future<void> startWorkout(BuildContext context, WorkoutDay day) async {
  final scope = AppScope.of(context);
  final controller = scope.workout;
  final active = controller.session;

  if (active != null && active.dayId == day.id) {
    await openSession(context);
    return;
  }
  if (active != null) {
    final replace = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tienes un entrenamiento a medias'),
        content: Text('"${active.dayTitle}" sigue en curso. ¿Quieres descartarlo y empezar este?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Empezar nuevo')),
        ],
      ),
    );
    if (replace != true) return;
  }
  if (day.activeExercises.isEmpty) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Este día no tiene ejercicios activos. Añádelos en Editar rutina.')),
    );
    return;
  }
  await controller.start(scope.plans.active, day);
  if (context.mounted) await openSession(context);
}

Future<void> openSession(BuildContext context) =>
    Navigator.of(context).push(MaterialPageRoute(fullscreenDialog: true, builder: (_) => const SessionScreen()));
