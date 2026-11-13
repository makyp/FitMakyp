import 'package:flutter/material.dart';

import '../../../app_scope.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/line_chart.dart';
import '../../library/ui/exercise_detail_screen.dart';
import '../domain/strength.dart';

/// Mis récords: peso máximo, 1RM estimado y repeticiones por ejercicio.
class RecordsScreen extends StatelessWidget {
  const RecordsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return ListenableBuilder(
      listenable: scope.history,
      builder: (context, _) {
        final t = Theme.of(context).textTheme;
        final all = allRecords(scope.history.sessions);
        final withWeight = all.where((r) => r.hasWeight).toList();
        final others = all.where((r) => !r.hasWeight).toList();
        return Scaffold(
          appBar: AppBar(title: const Text('Mis récords')),
          body: all.isEmpty
              ? const EmptyHint(
                  icon: Icons.emoji_events_outlined,
                  title: 'Aún no hay récords',
                  text: 'Al entrenar, anota el peso y las repeticiones de cada serie y aquí verás tu progreso.',
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                  children: [
                    Text(
                      'Toca un ejercicio para ver su gráfica. El 1RM estimado es una referencia calculada '
                      '(no hace falta probar tu máximo).',
                      style: t.bodySmall?.copyWith(color: FmColors.muted),
                    ),
                    if (withWeight.isNotEmpty) const SectionTitle('Con peso'),
                    for (final r in withWeight) _RecordCard(r: r),
                    if (others.isNotEmpty) const SectionTitle('Sin peso'),
                    for (final r in others) _RecordCard(r: r),
                  ],
                ),
        );
      },
    );
  }
}

class _RecordCard extends StatelessWidget {
  const _RecordCard({required this.r});
  final ExerciseRecords r;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final h = r.heaviest;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          leading: CircleAvatar(
            backgroundColor: FmColors.lavender,
            child: Text(h != null ? '🏋️' : '💪'),
          ),
          title: Text(r.name, style: t.titleMedium),
          subtitle: Text(
            h != null
                ? 'Máximo: ${formatKg(h.weight!)} × ${h.reps} · ${r.sessions} ${r.sessions == 1 ? 'vez' : 'veces'}'
                : 'Récord: ${r.mostReps?.reps ?? 0} reps · ${r.sessions} ${r.sessions == 1 ? 'vez' : 'veces'}',
          ),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ExerciseDetailScreen(exerciseId: r.exerciseId)),
          ),
        ),
      ),
    );
  }
}

/// Sección "Tu progreso" para el detalle de un ejercicio.
class ExerciseProgressSection extends StatelessWidget {
  const ExerciseProgressSection({super.key, required this.exerciseId});
  final String exerciseId;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final t = Theme.of(context).textTheme;
    final r = exerciseRecords(scope.history.sessions, exerciseId);
    if (r.sessions == 0) return const SizedBox.shrink();
    final last = lastPerformance(scope.history.sessions, exerciseId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle('Tu progreso'),
        Row(
          children: [
            if (r.heaviest != null) ...[
              Expanded(child: StatTile(value: formatKg(r.heaviest!.weight!), label: 'Peso máximo', highlight: true)),
              const SizedBox(width: 10),
              Expanded(child: StatTile(value: formatKg(r.bestE1rm!.e1rm!.roundToDouble()), label: '1RM estimado')),
            ] else
              Expanded(child: StatTile(value: '${r.mostReps?.reps ?? 0}', label: 'Más reps', highlight: true)),
            const SizedBox(width: 10),
            Expanded(child: StatTile(value: '${r.sessions}', label: r.sessions == 1 ? 'Vez' : 'Veces')),
          ],
        ),
        if (last != null) ...[
          const SizedBox(height: 10),
          Text('Última vez (${formatShortDate(last.$1.startedAt)}): ${describeSets(last.$2)}', style: t.bodyMedium),
        ],
        if (r.weightSeries.length >= 2) ...[
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 14, 16, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Peso máximo por entrenamiento', style: t.labelLarge),
                  const SizedBox(height: 8),
                  SimpleLineChart(points: r.weightSeries, unit: 'kg', height: 160),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
