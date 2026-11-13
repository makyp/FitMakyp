import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../core/models/body.dart';
import '../../core/models/goal.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/line_chart.dart';
import '../../shared/widgets/progress_photo.dart';
import '../goals/ui/goals_screen.dart';
import '../../core/models/exercise.dart';
import 'domain/muscle_map.dart';
import 'domain/progress_analysis.dart';
import 'ui/body_map.dart';
import 'ui/bmi_card.dart';
import 'ui/checkin_sheet.dart';
import 'ui/mood_screen.dart';
import 'ui/silhouette_screen.dart';
import 'ui/compare_screen.dart';
import 'ui/delta_text.dart';
import 'ui/measure_detail_screen.dart';
import 'ui/record_form_screen.dart';

/// Mi evolución: peso, medidas, fotos, comparador y registro diario.
class EvolutionScreen extends StatelessWidget {
  const EvolutionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([scope.body, scope.goals, scope.history]),
      builder: (context, _) {
        final body = scope.body;
        final t = Theme.of(context).textTheme;
        final now = DateTime.now();
        final records = body.records;
        final weightGoal = scope.goals.active.where((g) => g.type == GoalType.weight).firstOrNull;
        final checkedToday = body.checkinFor(now) != null;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Mi evolución'),
            actions: [
              IconButton(
                tooltip: 'Metas',
                icon: const Icon(Icons.flag_outlined),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GoalsScreen())),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RecordFormScreen())),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Registrar'),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
            children: [
              _EvaluationCard(daysLeft: body.daysToEvaluation(now), every: body.evaluationEveryDays),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                  leading: Icon(checkedToday ? Icons.check_circle_rounded : Icons.wb_sunny_outlined,
                      color: FmColors.primary),
                  title: Text(checkedToday ? 'Registro de hoy hecho' : '¿Cómo te sientes hoy?'),
                  subtitle: const Text('Ánimo, energía, descanso y actividad'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => showCheckinSheet(context),
                ),
              ),
              Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                  leading: Icon(Icons.show_chart_rounded, color: FmColors.primary),
                  title: const Text('Mi ánimo en el tiempo'),
                  subtitle: const Text('Gráfica de semanas y meses, con tus días de entreno'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MoodScreen())),
                ),
              ),
              const SizedBox(height: 12),
              if (scope.body.heightCm == null) ...[
                Card(
                  color: FmColors.lavender,
                  child: ListTile(
                    leading: Icon(Icons.height_rounded, color: FmColors.primary),
                    title: const Text('Añade tu estatura'),
                    subtitle: const Text('Con tu estatura y tu peso calculamos tu IMC'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => editHeight(context),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              const _SilhouettePreview(),
              if (records.isEmpty)
                const EmptyHint(
                  icon: Icons.insights_rounded,
                  title: 'Empieza tu seguimiento',
                  text: 'Pulsa "Registrar" para guardar tu peso, tus medidas y, si quieres, fotos. '
                      'Las fotos se quedan solo en tu teléfono.',
                )
              else ...[
                SectionTitle('Peso',
                    trailing: TextButton(
                      onPressed: () => Navigator.push(
                          context, MaterialPageRoute(builder: (_) => const MeasureDetailScreen(measure: Measure.peso))),
                      child: const Text('Ver todo'),
                    )),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(_v(body.latestValue(Measure.peso)), style: t.headlineMedium),
                            const SizedBox(width: 4),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Text('kg', style: t.titleMedium?.copyWith(color: FmColors.muted)),
                            ),
                            const Spacer(),
                            if (body.totalChange(Measure.peso) case final d?)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  DeltaText(delta: d, unit: 'kg'),
                                  Text('desde el inicio', style: t.labelSmall?.copyWith(color: FmColors.muted)),
                                ],
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SimpleLineChart(points: body.series(Measure.peso), unit: 'kg', target: weightGoal?.target),
                      ],
                    ),
                  ),
                ),
                const SectionTitle('IMC'),
                const BmiCard(),
                SectionTitle('Medidas',
                    trailing: TextButton.icon(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CompareScreen())),
                      icon: const Icon(Icons.compare_rounded, size: 18),
                      label: const Text('Comparar'),
                    )),
                Card(
                  child: Column(
                    children: [
                      for (final (i, m) in Measure.values.where((m) => m != Measure.peso && body.latestValue(m) != null).indexed) ...[
                        if (i > 0) const Divider(indent: 16, endIndent: 16),
                        ListTile(
                          title: Text(m.label),
                          subtitle: Text('${_v(body.latestValue(m))} ${m.unit}'),
                          trailing: body.lastChange(m) == null
                              ? const Icon(Icons.chevron_right_rounded)
                              : DeltaText(delta: body.lastChange(m)!, unit: m.unit),
                          onTap: () => Navigator.push(
                              context, MaterialPageRoute(builder: (_) => MeasureDetailScreen(measure: m))),
                        ),
                      ],
                      if (Measure.values.every((m) => m == Measure.peso || body.latestValue(m) == null))
                        const ListTile(title: Text('Aún no has registrado medidas.')),
                    ],
                  ),
                ),
                SectionTitle('Registros (${records.length})'),
                for (final r in records.reversed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _RecordTile(record: r),
                  ),
              ],
              const SizedBox(height: 8),
              Text(
                'Los valores son orientativos y no sustituyen una valoración profesional.',
                style: t.bodySmall?.copyWith(color: FmColors.muted),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }

  static String _v(double? v) => v == null ? '—' : (v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1));
}

class _EvaluationCard extends StatelessWidget {
  const _EvaluationCard({required this.daysLeft, required this.every});
  final int? daysLeft;
  final int every;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final due = daysLeft == null || daysLeft! <= 0;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(colors: [FmColors.deep, FmColors.primary]),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('EVALUACIÓN CADA $every DÍAS',
                    style: t.labelSmall?.copyWith(color: const Color(0xFFDCCBFA), letterSpacing: 1.2, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(
                  daysLeft == null
                      ? 'Haz tu primera evaluación'
                      : due
                          ? '¡Te toca evaluación!'
                          : 'Próxima en $daysLeft ${daysLeft == 1 ? 'día' : 'días'}',
                  style: t.titleLarge?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text('Peso, medidas y fotos frontal, lateral y posterior.',
                    style: t.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.8))),
              ],
            ),
          ),
          if (due)
            IconButton.filled(
              style: IconButton.styleFrom(backgroundColor: Colors.white, foregroundColor: FmColors.primary),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RecordFormScreen())),
              icon: const Icon(Icons.arrow_forward_rounded),
            ),
        ],
      ),
    );
  }
}

class _RecordTile extends StatelessWidget {
  const _RecordTile({required this.record});
  final ProgressRecord record;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final r = record;
    final w = r.values[Measure.peso];
    final others = r.values.length - (w == null ? 0 : 1);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RecordFormScreen(recordId: r.id))),
        onLongPress: () => _delete(context),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              SizedBox(
                width: 56,
                height: 72,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: r.photos.isEmpty
                      ? ColoredBox(
                          color: FmColors.line, child: Icon(Icons.straighten_rounded, color: FmColors.lilac))
                      : ProgressPhoto(photoId: (r.photos[PhotoAngle.frontal] ?? r.photos.values.first)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(formatLongDate(r.date), style: t.titleSmall),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (w != null) '${w.toStringAsFixed(w == w.roundToDouble() ? 0 : 1)} kg',
                        if (others > 0) '$others medidas',
                        if (r.photos.isNotEmpty) '${r.photos.length} ${r.photos.length == 1 ? 'foto' : 'fotos'}',
                      ].join(' · '),
                      style: t.bodySmall?.copyWith(color: FmColors.muted),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: FmColors.muted),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _delete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar registro?'),
        content: const Text('Se borrarán sus medidas y fotos de este teléfono. No se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (ok == true && context.mounted) await AppScope.of(context).body.deleteRecord(record.id);
  }
}

/// Vista previa de Mi cuerpo: frente y espalda con lo entrenado en 30 días y el resumen de mejoras.
class _SilhouettePreview extends StatelessWidget {
  const _SilhouettePreview();

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final t = Theme.of(context).textTheme;
    final records = scope.body.records;
    final trends = effectiveTrends(scope);
    final pair = comparePair(scope.body, CompareMode.inicio);
    final comps = pair == null ? const <MeasureComparison>[] : compareRecords(pair.$1.values, pair.$2.values, trends);
    final counts = <ImprovementTier, int>{};
    for (final c in comps.where((c) => c.trend != Trend.neutral)) {
      counts[c.tier] = (counts[c.tier] ?? 0) + 1;
    }
    final best = comps.where((c) => c.trend != Trend.neutral && c.tier != ImprovementTier.gris).firstOrNull;
    final training = trainingMap(scope.history.sessions, scope.library.byId, TrainingPeriod.mes, DateTime.now());
    final most = training.ranking.where((m) => m.muscle != MuscleGroup.cardio).firstOrNull;
    final values = records.isEmpty ? const <Measure, double>{} : filledValues(records, records.last);

    Color? colorOf(BodyZone z, int side) {
      final l = training.zoneLevel(z);
      return l == TrainingLevel.nada ? null : l.color;
    }

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SilhouetteScreen())),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 12, 16, 12),
          child: Row(
            children: [
              for (final v in BodyView.values)
                SizedBox(
                  width: 62,
                  child: BodyMap(
                    now: values,
                    heightCm: scope.body.heightCm ?? 165,
                    height: 170,
                    colorOf: colorOf,
                    interactive: false,
                    view: v,
                  ),
                ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Mi cuerpo 360°', style: t.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      most == null
                          ? 'Tus músculos se colorean según lo que entrenes.'
                          : 'Lo más entrenado en 30 días: ${most.muscle.label}.',
                      style: t.bodySmall?.copyWith(color: FmColors.muted),
                    ),
                    if (best != null)
                      Text(
                        'Mejor mejora: ${best.measure.label} (${best.progressPercent.toStringAsFixed(1)} %).',
                        style: t.bodySmall?.copyWith(color: FmColors.muted),
                      ),
                    if (counts.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final tier in [
                            ImprovementTier.morado,
                            ImprovementTier.azul,
                            ImprovementTier.amarillo,
                            ImprovementTier.gris,
                          ])
                            if (counts[tier] != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: tier.color.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: tier.color),
                                ),
                                child: Text('${tier.label}: ${counts[tier]}', style: t.labelSmall),
                              ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text('Ver músculos y medidas →', style: t.labelLarge?.copyWith(color: FmColors.primary)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
