import 'package:flutter/material.dart';

import '../../../app_scope.dart';
import '../../../core/theme/app_theme.dart';
import 'day_editor_screen.dart';

/// Rutina semanal: un día por fila. Tocar un día abre su editor.
class PlanScreen extends StatelessWidget {
  const PlanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return ListenableBuilder(
      listenable: scope.plans,
      builder: (context, _) {
        final plan = scope.plans.active;
        final t = Theme.of(context).textTheme;
        final days = [...plan.days]..sort((a, b) => a.weekday.compareTo(b.weekday));
        return Scaffold(
          appBar: AppBar(
            title: Text(plan.name),
            actions: [
              if (scope.plans.plans.length > 1)
                IconButton(
                  tooltip: 'Mis rutinas',
                  icon: const Icon(Icons.swap_horiz_rounded),
                  onPressed: () => _showPlans(context),
                ),
            ],
          ),
          body: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
            itemCount: days.length + (scope.plans.plans.length > 1 ? 1 : 0),
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              if (i == days.length) {
                return TextButton.icon(
                  onPressed: () => _showPlans(context),
                  icon: const Icon(Icons.swap_horiz_rounded),
                  label: Text('Tienes ${scope.plans.plans.length} rutinas guardadas · cambiar'),
                );
              }
              final d = days[i];
              final active = d.activeExercises.length;
              final disabled = d.exercises.length - active;
              return Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: d.isTraining ? FmColors.lavender : FmColors.warmWhite,
                    foregroundColor: FmColors.primary,
                    child: Text(d.weekdayName.substring(0, 2), style: const TextStyle(fontWeight: FontWeight.w800)),
                  ),
                  title: Text(d.title, style: t.titleMedium),
                  subtitle: Text(
                    d.isTraining
                        ? '${d.weekdayName} · $active ejercicios${disabled > 0 ? ' ($disabled desactivados)' : ''}'
                        : '${d.weekdayName} · Recuperación',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DayEditorScreen(dayId: d.id))),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

Future<void> _showPlans(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: FmColors.surface,
      builder: (ctx) {
        final repo = AppScope.of(context).plans;
        return ListenableBuilder(
          listenable: repo,
          builder: (ctx, _) => SafeArea(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: Text('Mis rutinas', style: Theme.of(ctx).textTheme.titleMedium),
                ),
                for (final p in repo.plans)
                  ListTile(
                    leading: Icon(
                      p.id == repo.active.id ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                      color: FmColors.primary,
                    ),
                    title: Text(p.name),
                    subtitle: Text(() {
                      final n = p.days.where((d) => d.isTraining).length;
                      return '$n ${n == 1 ? 'día' : 'días'} de entrenamiento';
                    }()),
                    onTap: () => repo.setActive(p.id),
                    trailing: p.id == repo.active.id
                        ? const Text('Activa')
                        : IconButton(
                            tooltip: 'Borrar rutina',
                            icon: const Icon(Icons.delete_outline_rounded),
                            onPressed: () async {
                              final ok = await showDialog<bool>(
                                context: ctx,
                                builder: (d) => AlertDialog(
                                  title: Text('¿Borrar "${p.name}"?'),
                                  content: const Text('Tu historial de entrenamientos no se borra.'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancelar')),
                                    FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Borrar')),
                                  ],
                                ),
                              );
                              if (ok == true) await repo.delete(p.id);
                            },
                          ),
                  ),
              ],
            ),
          ),
        );
      },
    );
