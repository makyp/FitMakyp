import 'package:flutter/material.dart';

import '../../../app_scope.dart';
import '../../../core/models/body.dart';
import '../../../core/models/goal.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/line_chart.dart';
import 'delta_text.dart';

/// Historial y gráfica de una medida, con selector de periodo.
class MeasureDetailScreen extends StatefulWidget {
  const MeasureDetailScreen({super.key, required this.measure});
  final Measure measure;

  @override
  State<MeasureDetailScreen> createState() => _MeasureDetailScreenState();
}

enum _Period {
  m1('1 mes', 31),
  m3('3 meses', 92),
  m6('6 meses', 183),
  all('Todo', 0);

  const _Period(this.label, this.days);
  final String label;
  final int days;
}

class _MeasureDetailScreenState extends State<MeasureDetailScreen> {
  _Period _period = _Period.all;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final t = Theme.of(context).textTheme;
    final m = widget.measure;
    return ListenableBuilder(
      listenable: Listenable.merge([scope.body, scope.goals]),
      builder: (context, _) {
        final all = scope.body.series(m);
        final from = _period.days == 0 ? null : DateTime.now().subtract(Duration(days: _period.days));
        final pts = from == null ? all : all.where((p) => !p.$1.isBefore(from)).toList();
        final goal = scope.goals.active.where((g) =>
            (m == Measure.peso && g.type == GoalType.weight) || (g.type == GoalType.measure && g.measure == m));
        final change = pts.length >= 2 ? MeasureDelta(pts.first.$2, pts.last.$2) : null;

        return Scaffold(
          appBar: AppBar(title: Text(m.label)),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
            children: [
              SegmentedButton<_Period>(
                showSelectedIcon: false,
                segments: [for (final p in _Period.values) ButtonSegment(value: p, label: Text(p.label))],
                selected: {_period},
                onSelectionChanged: (v) => setState(() => _period = v.first),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 16, 16, 12),
                  child: SimpleLineChart(
                    points: pts,
                    unit: m.unit,
                    height: 220,
                    target: goal.isEmpty ? null : goal.first.target,
                  ),
                ),
              ),
              if (change != null) ...[
                const SizedBox(height: 12),
                Card(
                  child: ListTile(
                    title: Text('Cambio en el periodo'),
                    subtitle: Text('${formatShortDate(pts.first.$1)} → ${formatShortDate(pts.last.$1)}'),
                    trailing: DeltaText(delta: change, unit: m.unit),
                  ),
                ),
              ],
              SectionTitle('Historial (${all.length})'),
              if (all.isEmpty)
                Text('Aún no has registrado ${m.label.toLowerCase()}.', style: t.bodyMedium?.copyWith(color: FmColors.muted))
              else
                Card(
                  child: Column(
                    children: [
                      for (final (i, p) in all.reversed.indexed) ...[
                        if (i > 0) const Divider(indent: 16, endIndent: 16),
                        ListTile(
                          dense: true,
                          title: Text('${_f(p.$2)} ${m.unit}'),
                          subtitle: Text(formatLongDate(p.$1)),
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
  }

  static String _f(double v) => v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);
}
