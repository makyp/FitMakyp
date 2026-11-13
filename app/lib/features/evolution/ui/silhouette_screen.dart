import 'package:flutter/material.dart';

import '../../../app_scope.dart';
import '../../../core/models/body.dart';
import '../../../core/models/goal.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../core/models/exercise.dart';
import '../../../shared/widgets/common.dart';
import '../domain/muscle_map.dart';
import '../domain/progress_analysis.dart';
import '../state/body_repository.dart';
import '../../plans/ui/add_to_day_sheet.dart';
import '../../plans/ui/ai_plan_screen.dart';
import '../../library/ui/exercise_detail_screen.dart';
import 'bmi_card.dart';
import 'body_map.dart';

enum CompareMode { inicio, mes }

/// Objetivos efectivos: si hay una meta de peso activa, el peso sigue su dirección.
Map<Measure, Trend> effectiveTrends(AppScope scope) {
  final t = Map.of(scope.body.trends);
  final g = scope.goals.active.where((g) => g.type == GoalType.weight && g.startValue != null).firstOrNull;
  if (g != null) t[Measure.peso] = g.target < g.startValue! ? Trend.reduce : Trend.increase;
  return t;
}

/// Registros a comparar según el modo: (antes, ahora). Null si no hay suficientes.
(ProgressRecord, ProgressRecord)? comparePair(BodyRepository body, CompareMode mode) {
  final r = body.records;
  if (r.length < 2) return null;
  final before = mode == CompareMode.inicio ? r.first : monthAgoRecord(r);
  return before == null ? null : (before, r.last);
}

/// Mi cuerpo: mapa muscular 360° generado con las medidas. Muestra cuánto se ha entrenado cada
/// músculo y cómo han cambiado las medidas por zonas, con la categoría de colores.
class SilhouetteScreen extends StatefulWidget {
  const SilhouetteScreen({super.key, this.mode = CompareMode.inicio, this.measures = false});
  final CompareMode mode;

  /// true para abrir en la vista de medidas.
  final bool measures;

  @override
  State<SilhouetteScreen> createState() => _SilhouetteScreenState();
}

class _SilhouetteScreenState extends State<SilhouetteScreen> {
  late CompareMode _mode = widget.mode;
  late bool _measures = widget.measures;
  TrainingPeriod _period = TrainingPeriod.mes;
  BodyZone? _selected;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([scope.body, scope.goals, scope.history, scope.library, scope.plans]),
      builder: (context, _) {
        final t = Theme.of(context).textTheme;
        final body = scope.body;
        final records = body.records;
        final pair = comparePair(body, _mode);
        final trends = effectiveTrends(scope);
        final nowValues = records.isEmpty ? const <Measure, double>{} : filledValues(records, records.last);
        final beforeValues = pair == null ? null : filledValues(records, pair.$1);
        final comps = pair == null ? const <MeasureComparison>[] : compareRecords(pair.$1.values, pair.$2.values, trends);
        final withGoal = comps.where((c) => c.trend != Trend.neutral).toList();
        final top = withGoal.where((c) => c.tier != ImprovementTier.gris).take(3).toList();
        final training = trainingMap(scope.history.sessions, scope.library.byId, _period, DateTime.now());

        Color? colorOf(BodyZone z, int side) {
          if (_measures) return zoneTier(z, side, beforeValues, nowValues, trends)?.color;
          final level = training.zoneLevel(z);
          return level == TrainingLevel.nada ? null : level.color;
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Mi cuerpo'),
            actions: [
              IconButton(
                tooltip: 'Mis objetivos por medida',
                icon: const Icon(Icons.tune_rounded),
                onPressed: () => showTrendsSheet(context),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
            children: [
              SegmentedButton<bool>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: false, icon: Icon(Icons.fitness_center_rounded), label: Text('Entrenamiento')),
                  ButtonSegment(value: true, icon: Icon(Icons.straighten_rounded), label: Text('Medidas')),
                ],
                selected: {_measures},
                onSelectionChanged: (v) => setState(() => _measures = v.first),
              ),
              const SizedBox(height: 10),
              Center(
                child: _measures
                    ? SegmentedButton<CompareMode>(
                        showSelectedIcon: false,
                        style: const ButtonStyle(visualDensity: VisualDensity.compact),
                        segments: const [
                          ButtonSegment(value: CompareMode.inicio, label: Text('Desde el inicio')),
                          ButtonSegment(value: CompareMode.mes, label: Text('Último mes')),
                        ],
                        selected: {_mode},
                        onSelectionChanged: (v) => setState(() => _mode = v.first),
                      )
                    : SegmentedButton<TrainingPeriod>(
                        showSelectedIcon: false,
                        style: const ButtonStyle(visualDensity: VisualDensity.compact),
                        segments: [
                          for (final p in TrainingPeriod.values) ButtonSegment(value: p, label: Text(p.label)),
                        ],
                        selected: {_period},
                        onSelectionChanged: (v) => setState(() => _period = v.first),
                      ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 16, 8, 12),
                  child: Column(
                    children: [
                      BodyMap(
                        now: nowValues,
                        before: _measures ? beforeValues : null,
                        heightCm: body.heightCm ?? 165,
                        height: 420,
                        colorOf: colorOf,
                        selected: _selected,
                        onZoneTap: (z, side) => _openZone(context, z, side, training, pair, trends),
                      ),
                      const SizedBox(height: 10),
                      Text('Desliza para girar · toca un músculo para ver su detalle',
                          style: t.bodySmall?.copyWith(color: FmColors.muted)),
                      const SizedBox(height: 10),
                      if (_measures)
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 14,
                          runSpacing: 6,
                          children: [
                            if (pair != null) _Legend(dashed: true, label: 'Antes · ${formatShortDate(pair.$1.date)}'),
                            if (records.isNotEmpty) _Legend(label: 'Ahora · ${formatShortDate(records.last.date)}'),
                            for (final tier in ImprovementTier.values.reversed) _Dot(color: tier.color, label: tier.label),
                          ],
                        )
                      else
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 14,
                          runSpacing: 6,
                          children: [
                            for (final l in TrainingLevel.values.reversed) _Dot(color: l.color, label: l.label),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Figura orientativa generada con tus medidas${body.heightCm == null ? ' (estatura estimada 165 cm)' : ''}'
                '${records.isEmpty ? ' (aún sin medidas: se usan proporciones de referencia)' : ''}. '
                'Las medidas que falten se completan con tu último dato.',
                style: t.bodySmall?.copyWith(color: FmColors.muted),
              ),
              if (!_measures)
                ..._trainingSection(context, training)
              else if (records.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: EmptyHint(
                    icon: Icons.straighten_rounded,
                    title: 'Aún no hay medidas',
                    text: 'Registra tus medidas en Mi evolución y aquí verás qué zonas mejoran.',
                  ),
                )
              else ...[
                if (pair == null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text('Con un segundo registro de medidas verás qué zonas mejoran y su color.',
                        style: t.bodyMedium),
                  )
                else ...[
                  SectionTitle(
                    _mode == CompareMode.inicio
                        ? 'Tus mejores mejoras desde el inicio'
                        : 'Tus mejores mejoras del último mes',
                  ),
                  if (top.isEmpty)
                    Card(
                      child: ListTile(
                        leading: const Text('🌱', style: TextStyle(fontSize: 26)),
                        title: const Text('Los cambios llevan su tiempo'),
                        subtitle: Text(
                          withGoal.isEmpty
                              ? 'Elige qué quieres en cada medida (botón de ajustes arriba) para ver tus mejoras.'
                              : 'Sigue así: cada registro suma. La constancia es lo que cuenta.',
                        ),
                      ),
                    )
                  else
                    Row(
                      children: [
                        for (final (i, c) in top.indexed) ...[
                          if (i > 0) const SizedBox(width: 8),
                          Expanded(child: _PodiumCard(rank: i + 1, c: c)),
                        ],
                      ],
                    ),
                  const SectionTitle('Todas las medidas'),
                  Card(
                    child: Column(
                      children: [
                        for (final (i, c) in comps.indexed) ...[
                          if (i > 0) const Divider(indent: 16, endIndent: 16),
                          _ComparisonTile(c: c),
                        ],
                      ],
                    ),
                  ),
                  const SectionTitle('Qué significa cada color'),
                  Card(
                    child: Column(
                      children: [
                        for (final tier in ImprovementTier.values.reversed)
                          ListTile(
                            dense: true,
                            leading: CircleAvatar(radius: 9, backgroundColor: tier.color),
                            title: Text(tier.label),
                            subtitle: Text(tier.description),
                          ),
                      ],
                    ),
                  ),
                ],
                const SectionTitle('IMC'),
                const BmiCard(),
              ],
            ],
          ),
        );
      },
    );
  }

  List<Widget> _trainingSection(BuildContext context, TrainingMap training) {
    final t = Theme.of(context).textTheme;
    final ranking = training.ranking.where((m) => m.muscle != MuscleGroup.cardio).toList();
    final cardio = training.stats[MuscleGroup.cardio];
    final untrained = [
      for (final m in MuscleGroup.values)
        if (m != MuscleGroup.cardio && training.setsOf(m) == 0) m,
    ];
    final maxSets = ranking.isEmpty ? 1.0 : ranking.first.sets;
    return [
      SectionTitle('Cuánto has entrenado cada músculo (${_period == TrainingPeriod.todo ? 'todo' : 'últimos ${_period.label}'})'),
      if (ranking.isEmpty)
        const EmptyHint(
          icon: Icons.fitness_center_rounded,
          title: 'Aún no hay entrenamientos en este periodo',
          text: 'Cuando completes series, aquí verás qué músculos trabajaste y cuánto.',
        )
      else
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              children: [
                for (final m in ranking) _MuscleBar(stats: m, level: training.muscleLevel(m.muscle), maxSets: maxSets),
              ],
            ),
          ),
        ),
      if (cardio != null) ...[
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: Icon(Icons.directions_bike_rounded, color: FmColors.primary),
            title: const Text('Cardio'),
            subtitle: Text('${_n(cardio.sessions, 'sesión', 'sesiones')} · última el ${formatShortDate(cardio.last!)}'),
          ),
        ),
      ],
      if (untrained.isNotEmpty && ranking.isNotEmpty) ...[
        const SectionTitle('Sin entrenar en este periodo'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [for (final m in untrained) Chip(label: Text(m.label), visualDensity: VisualDensity.compact)],
        ),
      ],
      ..._suggestions(context),
      const SizedBox(height: 10),
      Text(
        'Cada serie cuenta 1 para el músculo principal del ejercicio y 0,5 para los secundarios. '
        'Los colores comparan tus series por semana: no hace falta tenerlo todo en morado, '
        'lo importante es que se ajuste a tu plan y te sientas bien.',
        style: t.bodySmall?.copyWith(color: FmColors.muted),
      ),
    ];
  }

  List<Widget> _suggestions(BuildContext context) {
    final scope = AppScope.of(context);
    final t = Theme.of(context).textTheme;
    final m14 = trainingMap(scope.history.sessions, scope.library.byId, TrainingPeriod.todo, DateTime.now(), days: 14);
    final inPlan = {for (final d in scope.plans.active.days) for (final e in d.exercises) e.exerciseId};
    final sugg = balanceSuggestions(m14, scope.library.all, inPlan);
    if (sugg.isEmpty) return const [];
    return [
      const SectionTitle('Sugerencias para equilibrar'),
      Text('Según tus últimas 2 semanas. Toca un ejercicio para agregarlo a tu rutina.',
          style: t.bodySmall?.copyWith(color: FmColors.muted)),
      const SizedBox(height: 8),
      for (final s in sugg)
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(radius: 7, backgroundColor: m14.muscleLevel(s.muscle).color),
                    const SizedBox(width: 8),
                    Text(s.muscle.label, style: t.titleMedium),
                  ],
                ),
                const SizedBox(height: 4),
                Text(s.reason, style: t.bodyMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final ex in s.exercises)
                      ActionChip(
                        avatar: Icon(
                          inPlan.contains(ex.id) ? Icons.check_rounded : Icons.add_rounded,
                          size: 18,
                          color: FmColors.primary,
                        ),
                        label: Text(ex.name),
                        onPressed: () => _exerciseActions(context, ex),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      const SizedBox(height: 4),
      OutlinedButton.icon(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => AiPlanScreen(focus: {for (final s in sugg) s.muscle})),
        ),
        icon: const Icon(Icons.auto_awesome_rounded),
        label: const Text('Pedirle a la IA una rutina equilibrada'),
      ),
    ];
  }

  Future<void> _exerciseActions(BuildContext context, Exercise ex) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: FmColors.surface,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.add_circle_outline_rounded, color: FmColors.primary),
              title: Text('Agregar "${ex.name}" a mi rutina'),
              onTap: () => Navigator.pop(ctx, 'add'),
            ),
            ListTile(
              leading: Icon(Icons.info_outline_rounded, color: FmColors.primary),
              title: const Text('Ver cómo se hace'),
              onTap: () => Navigator.pop(ctx, 'see'),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted) return;
    if (action == 'add') {
      await showAddToDaySheet(context, ex);
    } else if (action == 'see') {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => ExerciseDetailScreen(exerciseId: ex.id)));
    }
  }

  Future<void> _openZone(
    BuildContext context,
    BodyZone zone,
    int side,
    TrainingMap training,
    (ProgressRecord, ProgressRecord)? pair,
    Map<Measure, Trend> trends,
  ) async {
    setState(() => _selected = zone);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: FmColors.surface,
      builder: (ctx) {
        final t = Theme.of(ctx).textTheme;
        final level = training.zoneLevel(zone);
        final sets = training.zoneSets(zone);
        final stats = [for (final m in zone.muscles) ?training.stats[m]];
        final sessionIds = {for (final s in stats) ...s.sessionIds};
        DateTime? last;
        final byEx = <String, double>{};
        for (final s in stats) {
          if (s.last != null && (last == null || s.last!.isAfter(last))) last = s.last;
          s.byExercise.forEach((k, v) => byEx[k] = (byEx[k] ?? 0) + v);
        }
        final topEx = byEx.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
        final m = zone.measure(side);
        final from = m == null ? null : pair?.$1.values[m];
        final to = m == null ? null : pair?.$2.values[m];
        final comp = (m == null || from == null || to == null)
            ? null
            : MeasureComparison(measure: m, from: from, to: to, trend: trends[m] ?? Trend.neutral);
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(zone.label, style: t.titleLarge),
                if (zone.muscles.length > 1 || zone.muscles.first.label != zone.label)
                  Text('Trabaja: ${zone.muscles.map((x) => x.label).join(' · ')}',
                      style: t.bodySmall?.copyWith(color: FmColors.muted)),
                const SizedBox(height: 14),
                Row(
                  children: [
                    CircleAvatar(radius: 10, backgroundColor: level.color),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        sets == 0
                            ? 'Sin series en ${_period == TrainingPeriod.todo ? 'tu historial' : 'los últimos ${_period.label}'}'
                            : '${_sets(sets)} series · ${_n(sessionIds.length, 'entrenamiento', 'entrenamientos')}',
                        style: t.titleMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text('${level.label}: ${level.description.toLowerCase()}',
                    style: t.bodySmall?.copyWith(color: FmColors.muted)),
                if (last != null) Text('Última vez: ${formatShortDate(last)}', style: t.bodyMedium),
                if (topEx.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text('Ejercicios que más la trabajaron', style: t.titleSmall),
                  for (final e in topEx.take(4))
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.fitness_center_rounded, size: 16, color: FmColors.lilac),
                          const SizedBox(width: 8),
                          Expanded(child: Text(e.key)),
                          Text('${_sets(e.value)} series', style: t.labelLarge),
                        ],
                      ),
                    ),
                ],
                if (m != null) ...[
                  const Divider(height: 28),
                  Text(m.label, style: t.titleSmall),
                  const SizedBox(height: 4),
                  if (comp == null)
                    Text(
                      pair == null
                          ? 'Con dos registros de medidas verás cómo cambia esta zona.'
                          : 'No tienes esta medida en los dos registros que se comparan.',
                      style: t.bodyMedium,
                    )
                  else
                    Row(
                      children: [
                        Container(
                          width: 10,
                          height: 34,
                          decoration: BoxDecoration(color: comp.tier.color, borderRadius: BorderRadius.circular(5)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '${_f(comp.from)} → ${_f(comp.to)} ${m.unit} (${_signed(comp.diff, m.unit)})\n'
                            '${comp.tier.label} ${_mode == CompareMode.inicio ? 'desde el inicio' : 'en el último mes'}',
                          ),
                        ),
                      ],
                    ),
                ],
              ],
            ),
          ),
        );
      },
    );
    if (mounted) setState(() => _selected = null);
  }
}

String _sets(double v) => v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1).replaceAll('.', ',');

String _n(int n, String one, String many) => '$n ${n == 1 ? one : many}';

class _Dot extends StatelessWidget {
  const _Dot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(radius: 6, backgroundColor: color),
          const SizedBox(width: 5),
          Text(label, style: Theme.of(context).textTheme.labelMedium),
        ],
      );
}

class _MuscleBar extends StatelessWidget {
  const _MuscleBar({required this.stats, required this.level, required this.maxSets});
  final MuscleStats stats;
  final TrainingLevel level;
  final double maxSets;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(stats.muscle.label, style: t.titleSmall)),
              Text('${_sets(stats.sets)} series', style: t.labelLarge?.copyWith(fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (stats.sets / maxSets).clamp(0.04, 1.0),
              minHeight: 10,
              color: level.color,
              backgroundColor: FmColors.line,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '${level.label} · ${_n(stats.sessions, 'entrenamiento', 'entrenamientos')} · última vez ${formatShortDate(stats.last!)}',
            style: t.labelSmall?.copyWith(color: FmColors.muted),
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.label, this.dashed = false});
  final String label;
  final bool dashed;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 22,
            height: 12,
            decoration: BoxDecoration(
              color: dashed ? null : FmColors.lavender,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: dashed ? FmColors.muted : FmColors.primary, width: 2),
            ),
          ),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.labelMedium),
        ],
      );
}

String _f(double v) => v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);

String _signed(double v, String unit) {
  final s = v > 0 ? '+' : (v < 0 ? '−' : '');
  return '$s${_f(v.abs())} $unit';
}

class _PodiumCard extends StatelessWidget {
  const _PodiumCard({required this.rank, required this.c});
  final int rank;
  final MeasureComparison c;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final color = c.tier.color;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 2),
      ),
      child: Column(
        children: [
          Text(['🥇', '🥈', '🥉'][rank - 1], style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 4),
          Text(c.measure.label, style: t.titleSmall, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(_signed(c.diff, c.measure.unit), style: t.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
          Text('${c.progressPercent.toStringAsFixed(1)} %', style: t.labelSmall?.copyWith(color: FmColors.muted)),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
            child: Text(
              c.tier.label,
              style: t.labelSmall?.copyWith(
                color: c.tier == ImprovementTier.amarillo ? FmColors.deep : Colors.white,
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class _ComparisonTile extends StatelessWidget {
  const _ComparisonTile({required this.c});
  final MeasureComparison c;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return ListTile(
      leading: Container(
        width: 12,
        height: 40,
        decoration: BoxDecoration(color: c.tier.color, borderRadius: BorderRadius.circular(6)),
      ),
      title: Text('${c.measure.label}  ${c.trend.symbol}'),
      subtitle: Text('${_f(c.from)} → ${_f(c.to)} ${c.measure.unit} · ${c.tier.label}'),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(_signed(c.diff, c.measure.unit), style: t.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
          Text('${c.percent >= 0 ? '+' : '−'}${c.percent.abs().toStringAsFixed(1)} %',
              style: t.labelSmall?.copyWith(color: FmColors.muted)),
        ],
      ),
    );
  }
}

/// Elegir qué se quiere en cada medida.
Future<void> showTrendsSheet(BuildContext context) => showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: FmColors.surface,
      builder: (ctx) {
        final scope = AppScope.of(context);
        return ListenableBuilder(
          listenable: scope.body,
          builder: (ctx, _) {
            final t = Theme.of(ctx).textTheme;
            final trends = scope.body.trends;
            final hasWeightGoal = scope.goals.active.any((g) => g.type == GoalType.weight);
            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.8,
              maxChildSize: 0.95,
              builder: (ctx, controller) => ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                children: [
                  Text('¿Qué quieres en cada medida?', style: t.titleLarge),
                  const SizedBox(height: 4),
                  Text('Así la app sabe qué cambio es una mejora para ti.',
                      style: t.bodySmall?.copyWith(color: FmColors.muted)),
                  const SizedBox(height: 12),
                  for (final m in Measure.values)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(m.label, style: t.titleSmall),
                          if (m == Measure.peso && hasWeightGoal)
                            Text('Usa la dirección de tu meta de peso activa.',
                                style: t.bodySmall?.copyWith(color: FmColors.muted))
                          else ...[
                            const SizedBox(height: 6),
                            SegmentedButton<Trend>(
                              showSelectedIcon: false,
                              segments: [
                                for (final tr in Trend.values) ButtonSegment(value: tr, label: Text('${tr.symbol} ${tr.label}')),
                              ],
                              selected: {trends[m] ?? Trend.neutral},
                              onSelectionChanged: (v) => scope.body.setTrend(m, v.first),
                            ),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
