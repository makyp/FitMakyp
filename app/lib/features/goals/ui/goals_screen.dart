import 'package:flutter/material.dart';

import '../../../app_scope.dart';
import '../../../core/models/body.dart';
import '../../../core/models/goal.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/ids.dart';
import '../../../shared/widgets/common.dart';
import '../domain/rewards.dart';

/// Metas personales con su progreso. Cada meta cumplida da puntos para la mascota.
class GoalsScreen extends StatelessWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return ListenableBuilder(
      listenable: scope.rewards,
      builder: (context, _) {
        final t = Theme.of(context).textTheme;
        final input = scope.rewards.input();
        final active = scope.goals.active;
        final done = scope.goals.completed;
        return Scaffold(
          appBar: AppBar(title: const Text('Mis metas')),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => showAddGoalSheet(context),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Nueva meta'),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
            children: [
              Text('Cada meta cumplida te da ${PointRules.goal} puntos para tu mascota.',
                  style: t.bodyMedium?.copyWith(color: FmColors.muted)),
              if (active.isEmpty)
                const EmptyHint(
                  icon: Icons.flag_outlined,
                  title: 'Sin metas activas',
                  text: 'Crea una: un peso, una medida, días seguidos o entrenamientos al mes.',
                ),
              for (final g in active) ...[
                const SizedBox(height: 10),
                GoalCard(goal: g, progress: scope.rewards.progressOf(g, input)),
              ],
              if (done.isNotEmpty) ...[
                SectionTitle('Cumplidas (${done.length})'),
                for (final g in done)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.emoji_events_rounded, color: Color(0xFFD69E2E)),
                      title: Text(g.title),
                      subtitle: Text('Cumplida el ${formatShortDate(g.completedAt!)} · +${PointRules.goal} puntos'),
                    ),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class GoalCard extends StatelessWidget {
  const GoalCard({super.key, required this.goal, required this.progress, this.compact = false});
  final Goal goal;
  final GoalProgress progress;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onLongPress: compact ? null : () => _remove(context),
        child: Padding(
          padding: EdgeInsets.all(compact ? 14 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(_icon(goal.type), color: FmColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text(goal.title, style: t.titleSmall)),
                  Text('${(progress.fraction * 100).round()} %',
                      style: t.labelLarge?.copyWith(color: FmColors.primary, fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progress.fraction,
                  minHeight: 8,
                  backgroundColor: FmColors.line,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Ahora: ${progress.current} · Meta: ${progress.target} ${goal.type.unit}',
                style: t.bodySmall?.copyWith(color: FmColors.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static IconData _icon(GoalType t) => switch (t) {
        GoalType.weight => Icons.monitor_weight_outlined,
        GoalType.measure => Icons.straighten_rounded,
        GoalType.streak => Icons.local_fire_department_outlined,
        GoalType.workoutsMonth => Icons.fitness_center_rounded,
        GoalType.checkins => Icons.wb_sunny_outlined,
        GoalType.waterDays => Icons.water_drop_outlined,
      };

  Future<void> _remove(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Quitar esta meta?'),
        content: Text(goal.title),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Quitar')),
        ],
      ),
    );
    if (ok == true && context.mounted) await AppScope.of(context).goals.remove(goal.id);
  }
}

Future<void> showAddGoalSheet(BuildContext context) => showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: FmColors.surface,
      builder: (_) => const _AddGoalSheet(),
    );

class _AddGoalSheet extends StatefulWidget {
  const _AddGoalSheet();

  @override
  State<_AddGoalSheet> createState() => _AddGoalSheetState();
}

class _AddGoalSheetState extends State<_AddGoalSheet> {
  GoalType _type = GoalType.streak;
  Measure _measure = Measure.cintura;
  final _value = TextEditingController();
  String? _error;

  static const _suggest = {
    GoalType.streak: '7',
    GoalType.workoutsMonth: '16',
    GoalType.checkins: '20',
    GoalType.waterDays: '20',
  };

  @override
  void initState() {
    super.initState();
    _value.text = _suggest[_type] ?? '';
  }

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final scope = AppScope.of(context);
    final v = double.tryParse(_value.text.trim().replaceAll(',', '.'));
    if (v == null || v <= 0) {
      setState(() => _error = 'Escribe un número válido.');
      return;
    }
    double? start;
    if (_type == GoalType.weight || _type == GoalType.measure) {
      start = scope.body.latestValue(_type == GoalType.weight ? Measure.peso : _measure);
      if (start == null) {
        setState(() => _error = 'Primero registra tu valor actual en Mi evolución.');
        return;
      }
      if (start == v) {
        setState(() => _error = 'Ya estás en ese valor.');
        return;
      }
    }
    await scope.goals.add(Goal(
      id: newId('goal'),
      type: _type,
      target: _type == GoalType.weight || _type == GoalType.measure ? v : v.roundToDouble(),
      measure: _type == GoalType.measure ? _measure : null,
      startValue: start,
      createdAt: DateTime.now(),
    ));
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final body = AppScope.of(context).body;
    final current = switch (_type) {
      GoalType.weight => body.latestValue(Measure.peso),
      GoalType.measure => body.latestValue(_measure),
      _ => null,
    };
    final v = double.tryParse(_value.text.trim().replaceAll(',', '.'));
    final warning = (_type == GoalType.weight && current != null && v != null)
        ? weightGoalWarning(current: current, target: v)
        : null;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Nueva meta', style: t.titleLarge),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final g in GoalType.values)
                  ChoiceChip(
                    label: Text(g.label),
                    selected: _type == g,
                    onSelected: (_) => setState(() {
                      _type = g;
                      _value.text = _suggest[g] ?? '';
                      _error = null;
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            if (_type == GoalType.measure) ...[
              DropdownButtonFormField<Measure>(
                initialValue: _measure,
                decoration: const InputDecoration(labelText: 'Medida'),
                items: [
                  for (final m in Measure.values.where((m) => m != Measure.peso))
                    DropdownMenuItem(value: m, child: Text(m.label)),
                ],
                onChanged: (m) => setState(() => _measure = m!),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _value,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() => _error = null),
              decoration: InputDecoration(
                labelText: 'Objetivo',
                suffixText: _type.unit,
                helperText: current == null ? null : 'Ahora: ${current.toStringAsFixed(1)} ${_type.unit}',
                errorText: _error,
              ),
            ),
            if (warning != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: FmColors.lavender, borderRadius: BorderRadius.circular(14)),
                child: Text(warning, style: t.bodySmall),
              ),
            ],
            if (_type == GoalType.weight && current != null && v != null && v != current) ...[
              const SizedBox(height: 8),
              Text(
                'A un ritmo saludable, unas ${suggestedWeeks(current, v)} semanas o más. Sin prisa.',
                style: t.bodySmall?.copyWith(color: FmColors.muted),
              ),
            ],
            const SizedBox(height: 18),
            FilledButton(onPressed: _save, child: const Text('CREAR META')),
          ],
        ),
      ),
    );
  }
}
