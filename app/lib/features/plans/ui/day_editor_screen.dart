import 'package:flutter/material.dart';

import '../../../app_scope.dart';
import '../../../core/models/exercise.dart';
import '../../../core/models/plan.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/ids.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/exercise_thumb.dart';
import '../../library/ui/library_screen.dart';
import '../../workout/ui/start_workout.dart';
import 'workout_exercise_sheet.dart';

/// Editor de un día: título, tipo (entreno/descanso) y ejercicios (orden, series, reps, descanso, activar).
class DayEditorScreen extends StatelessWidget {
  const DayEditorScreen({super.key, required this.dayId});
  final String dayId;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([scope.plans, scope.library, scope.settings]),
      builder: (context, _) {
        final day = scope.plans.dayById(dayId);
        if (day == null) return const Scaffold(body: Center(child: Text('Día no encontrado')));
        final t = Theme.of(context).textTheme;
        final defaultRest = scope.settings.settings.defaultRestSeconds;
        Future<void> save(WorkoutDay d) => scope.plans.updateDay(d);

        return Scaffold(
          appBar: AppBar(
            title: Text(day.weekdayName),
            actions: [
              IconButton(
                tooltip: 'Cambiar nombre',
                icon: const Icon(Icons.edit_rounded),
                onPressed: () => _rename(context, day),
              ),
            ],
          ),
          floatingActionButton: day.isTraining
              ? FloatingActionButton.extended(
                  onPressed: () => _addExercise(context, day),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Añadir ejercicio'),
                )
              : null,
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
            children: [
              Text(day.title, style: t.headlineSmall),
              const SizedBox(height: 12),
              SegmentedButton<DayKind>(
                segments: const [
                  ButtonSegment(value: DayKind.training, label: Text('Entrenamiento'), icon: Icon(Icons.fitness_center)),
                  ButtonSegment(value: DayKind.rest, label: Text('Recuperación'), icon: Icon(Icons.spa_outlined)),
                ],
                selected: {day.kind},
                onSelectionChanged: (v) => save(day.copyWith(kind: v.first)),
              ),
              if (day.isTraining && day.activeExercises.isNotEmpty) ...[
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: () => startWorkout(context, day),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('INICIAR ESTE DÍA'),
                ),
              ],
              if (!day.isTraining)
                const EmptyHint(
                  icon: Icons.spa_outlined,
                  title: 'Día de recuperación',
                  text: 'Los días de descanso no rompen tu racha. Puedes caminar, estirar o simplemente descansar.',
                )
              else ...[
                SectionTitle('Ejercicios (${day.exercises.length})',
                    trailing: Text('Mantén pulsado para reordenar', style: t.labelSmall?.copyWith(color: FmColors.muted))),
                if (day.exercises.isEmpty)
                  const EmptyHint(
                    icon: Icons.add_circle_outline_rounded,
                    title: 'Sin ejercicios',
                    text: 'Añade ejercicios desde la biblioteca.',
                  ),
                ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  buildDefaultDragHandles: false,
                  itemCount: day.exercises.length,
                  onReorderItem: (from, to) {
                    final list = [...day.exercises];
                    list.insert(to, list.removeAt(from));
                    save(day.copyWith(exercises: list));
                  },
                  itemBuilder: (context, i) {
                    final we = day.exercises[i];
                    final ex = scope.library.byId(we.exerciseId);
                    final rest = we.restSeconds ?? defaultRest;
                    return Padding(
                      key: ValueKey(we.id),
                      padding: const EdgeInsets.only(bottom: 8),
                      child: ReorderableDelayedDragStartListener(
                        index: i,
                        child: Card(
                          child: Opacity(
                            opacity: we.enabled ? 1 : 0.5,
                            child: ListTile(
                              contentPadding: const EdgeInsets.fromLTRB(10, 4, 4, 4),
                              leading: ExerciseThumb(src: ex?.media.src, number: i + 1),
                              title: Text(ex?.name ?? we.exerciseId),
                              subtitle: Text(
                                '${we.sets} × ${we.target.label} · descanso ${formatClock(Duration(seconds: rest))}'
                                '${we.enabled ? '' : ' · desactivado'}',
                              ),
                              trailing: Switch(
                                value: we.enabled,
                                onChanged: (v) {
                                  final list = [...day.exercises];
                                  list[i] = we.copyWith(enabled: v);
                                  save(day.copyWith(exercises: list));
                                },
                              ),
                              onTap: () async {
                                final result = await showWorkoutExerciseSheet(
                                  context,
                                  initial: we,
                                  exerciseName: ex?.name ?? we.exerciseId,
                                  defaultRest: defaultRest,
                                );
                                if (result == null) return;
                                final list = [...day.exercises];
                                if (result.delete) {
                                  list.removeAt(i);
                                } else {
                                  list[i] = result.value!;
                                }
                                await save(day.copyWith(exercises: list));
                              },
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _rename(BuildContext context, WorkoutDay day) async {
    final ctrl = TextEditingController(text: day.title);
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nombre del día'),
        content: TextField(controller: ctrl, autofocus: true, textCapitalization: TextCapitalization.sentences),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Guardar')),
        ],
      ),
    );
    if (value == null || value.isEmpty || !context.mounted) return;
    await AppScope.of(context).plans.updateDay(day.copyWith(title: value));
  }

  Future<void> _addExercise(BuildContext context, WorkoutDay day) async {
    final picked = await Navigator.push<Exercise>(
      context,
      MaterialPageRoute(builder: (_) => const LibraryScreen(pickMode: true)),
    );
    if (picked == null || !context.mounted) return;
    final we = WorkoutExercise(
      id: newId('we'),
      exerciseId: picked.id,
      sets: 3,
      target: picked.suggestedTarget,
    );
    await AppScope.of(context).plans.updateDay(day.copyWith(exercises: [...day.exercises, we]));
  }
}
