import '../../summary/month_summary_screen.dart';
import '../../morning/ui/morning_screen.dart';
import 'package:flutter/material.dart';

import '../../../app_scope.dart';
import '../../../core/models/plan.dart';
import '../../../core/theme/app_theme.dart';
import '../../library/ui/library_screen.dart';
import '../../plans/ui/day_editor_screen.dart';
import '../../plans/ui/plan_screen.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/exercise_media_view.dart';
import '../../plans/ui/ai_plan_screen.dart';
import '../../report/report_screen.dart';
import 'records_screen.dart';
import 'start_workout.dart';

/// Pestaña Entrenar: entrenamiento de hoy, otros días y accesos a rutina y biblioteca.
class WorkoutTabScreen extends StatelessWidget {
  const WorkoutTabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([scope.plans, scope.library, scope.workout]),
      builder: (context, _) {
        final plan = scope.plans.active;
        final today = scope.plans.today;
        final active = scope.workout.session;
        final t = Theme.of(context).textTheme;

        return Scaffold(
          appBar: AppBar(title: const Text('Entrenar')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
            children: [
              if (active != null)
                Card(
                  color: FmColors.lavender,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                    leading: Icon(Icons.play_circle_fill_rounded, color: FmColors.primary, size: 34),
                    title: const Text('Entrenamiento en curso'),
                    subtitle: Text(active.dayTitle),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => openSession(context),
                  ),
                ),
              if (today != null) ...[
                const SectionTitle('Hoy'),
                _DayPreview(day: today, highlighted: true),
              ],
              SectionTitle('Toda la semana · ${plan.name}'),
              for (final d in plan.days)
                if (d.id != today?.id)
                  Padding(padding: const EdgeInsets.only(bottom: 10), child: _DayPreview(day: d)),
              const SectionTitle('Configurar'),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const PlanScreen())),
                      icon: const Icon(Icons.edit_calendar_rounded),
                      label: const Text('Editar rutina'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const LibraryScreen())),
                      icon: const Icon(Icons.menu_book_rounded),
                      label: const Text('Ejercicios'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Card(
                child: ListTile(
                  leading: const Text('🌅', style: TextStyle(fontSize: 24)),
                  title: const Text('Rutina matutina'),
                  subtitle: const Text('Hipopresivos de pie, guiados respiración a respiración'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MorningScreen())),
                ),
              ),
              Card(
                child: ListTile(
                  leading: Icon(Icons.auto_awesome_rounded, color: FmColors.primary),
                  title: const Text('Armar rutina con IA'),
                  subtitle: const Text('Gratis: copias, pegas y la app la crea'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AiPlanScreen())),
                ),
              ),
              Card(
                child: ListTile(
                  leading: Icon(Icons.emoji_events_rounded, color: FmColors.primary),
                  title: const Text('Mis récords'),
                  subtitle: const Text('Peso máximo y progreso por ejercicio'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RecordsScreen())),
                ),
              ),
              Card(
                child: ListTile(
                  leading: const Text('🗓️', style: TextStyle(fontSize: 24)),
                  title: const Text('Mi mes'),
                  subtitle: const Text('Tu resumen en una tarjeta para guardar'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MonthSummaryScreen())),
                ),
              ),
              Card(
                child: ListTile(
                  leading: Icon(Icons.picture_as_pdf_outlined, color: FmColors.primary),
                  title: const Text('Reporte para mi entrenador'),
                  subtitle: const Text('PDF con tu progreso del último mes'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportScreen())),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Puedes entrenar cualquier día de la rutina aunque no sea hoy.',
                style: t.bodySmall?.copyWith(color: FmColors.muted),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DayPreview extends StatelessWidget {
  const _DayPreview({required this.day, this.highlighted = false});
  final WorkoutDay day;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final t = Theme.of(context).textTheme;
    final exercises = day.activeExercises;
    final firstMedia = exercises.isEmpty ? null : scope.library.byId(exercises.first.exerciseId)?.media;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DayEditorScreen(dayId: day.id))),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(day.weekdayName.toUpperCase(),
                            style: t.labelSmall?.copyWith(color: FmColors.primary, letterSpacing: 1.2, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 2),
                        Text(day.title, style: t.titleMedium),
                        Text(
                          day.isTraining ? '${exercises.length} ejercicios' : 'Recuperación',
                          style: t.bodySmall?.copyWith(color: FmColors.muted),
                        ),
                      ],
                    ),
                  ),
                  if (day.isTraining && exercises.isNotEmpty)
                    IconButton.filled(
                      tooltip: 'Iniciar ${day.weekdayName}',
                      onPressed: () => startWorkout(context, day),
                      icon: const Icon(Icons.play_arrow_rounded),
                    )
                  else
                    const Icon(Icons.spa_outlined, color: FmColors.lilac),
                ],
              ),
              if (highlighted && firstMedia != null) ...[
                const SizedBox(height: 12),
                ExerciseMediaView(media: firstMedia, height: 140),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
