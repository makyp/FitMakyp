import '../../../core/utils/gender.dart';
import 'package:flutter/material.dart';

import '../../../app_scope.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/exercise_media_view.dart';
import '../../workout/ui/records_screen.dart';
import 'exercise_form_screen.dart';

class ExerciseDetailScreen extends StatelessWidget {
  const ExerciseDetailScreen({super.key, required this.exerciseId});
  final String exerciseId;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([scope.library, scope.history]),
      builder: (context, _) {
        final raw = scope.library.byId(exerciseId);
        if (raw == null) return Scaffold(appBar: AppBar(), body: const Center(child: Text('Ejercicio eliminado')));
        final t = Theme.of(context).textTheme;
        final e = genderExercise(raw, context.sex);
        return Scaffold(
          appBar: AppBar(
            title: const Text('Ejercicio'),
            actions: [
              IconButton(
                tooltip: 'Editar',
                icon: const Icon(Icons.edit_rounded),
                onPressed: () =>
                    Navigator.push(context, MaterialPageRoute(builder: (_) => ExerciseFormScreen(initial: raw))),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
            children: [
              ExerciseMediaView(media: e.media, height: 210),
              const SizedBox(height: 16),
              Text(e.name, style: t.headlineSmall),
              const SizedBox(height: 6),
              Text(e.description, style: t.bodyLarge?.copyWith(color: FmColors.muted)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(label: Text(e.primaryMuscle.label), avatar: const Icon(Icons.adjust_rounded, size: 16)),
                  for (final m in e.secondaryMuscles) Chip(label: Text(m.label)),
                  Chip(label: Text(e.difficulty.label), avatar: const Icon(Icons.speed_rounded, size: 16)),
                  for (final q in e.equipment) Chip(label: Text(q.label)),
                ],
              ),
              ExerciseProgressSection(exerciseId: exerciseId),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(child: _PositionCard(title: 'Posición inicial', text: e.startPosition)),
                  const SizedBox(width: 10),
                  Expanded(child: _PositionCard(title: 'Posición final', text: e.endPosition)),
                ],
              ),
              if (e.instructions.isNotEmpty) ...[
                const SectionTitle('Técnica'),
                for (final (i, s) in e.instructions.indexed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: FmColors.lavender,
                          child: Text('${i + 1}', style: t.labelSmall?.copyWith(fontWeight: FontWeight.w800)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Text(s, style: t.bodyLarge)),
                      ],
                    ),
                  ),
              ],
              if (e.commonMistakes.isNotEmpty) ...[
                const SectionTitle('Errores frecuentes'),
                for (final m in e.commonMistakes)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.close_rounded, size: 18, color: FmColors.lilac),
                        const SizedBox(width: 8),
                        Expanded(child: Text(m, style: t.bodyLarge)),
                      ],
                    ),
                  ),
              ],
              const SectionTitle('Sugerido'),
              Text(e.suggestedTarget.label, style: t.bodyLarge),
            ],
          ),
        );
      },
    );
  }
}

class _PositionCard extends StatelessWidget {
  const _PositionCard({required this.title, required this.text});
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: t.labelLarge?.copyWith(color: FmColors.primary)),
            const SizedBox(height: 4),
            Text(text.isEmpty ? '—' : text, style: t.bodyMedium),
          ],
        ),
      ),
    );
  }
}
