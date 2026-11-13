import 'package:flutter/material.dart';

import '../../../app_scope.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../domain/mood_trends.dart';
import 'checkin_sheet.dart';

const _faces = ['😞', '😕', '😐', '🙂', '😄'];
const _energyColor = Color(0xFF3FBF9F);

/// Mi ánimo: cómo cambian ánimo y energía en semanas o meses, con los días de entreno marcados.
class MoodScreen extends StatefulWidget {
  const MoodScreen({super.key});

  @override
  State<MoodScreen> createState() => _MoodScreenState();
}

class _MoodScreenState extends State<MoodScreen> {
  /// Días que se muestran: 28, 91 o 182.
  int _range = 28;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([scope.body, scope.history]),
      builder: (context, _) {
        final t = Theme.of(context).textTheme;
        final now = DateTime.now();
        final from = DateTime(now.year, now.month, now.day - _range + 1);
        final weekly = _range > 28;
        final checks = scope.body.checkins;
        final inRange = checks.where((c) => !c.date.isBefore(from)).toList();
        final series = moodSeries(checks, from: from, to: now, weekly: weekly);
        final trained = scope.history.trainedDates.where((d) => !d.isBefore(from)).toSet();
        final compare = moodWithAndWithoutTraining(inRange, trained);
        final best = bestWeekday(inRange);
        final recent = [...checks]..sort((a, b) => b.date.compareTo(a.date));

        return Scaffold(
          appBar: AppBar(title: const Text('Mi ánimo')),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => showCheckinSheet(context),
            icon: const Icon(Icons.edit_rounded),
            label: const Text('Registro de hoy'),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
            children: [
              SegmentedButton<int>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: 28, label: Text('4 semanas')),
                  ButtonSegment(value: 91, label: Text('3 meses')),
                  ButtonSegment(value: 182, label: Text('6 meses')),
                ],
                selected: {_range},
                onSelectionChanged: (v) => setState(() => _range = v.first),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 14, 14, 10),
                  child: Column(
                    children: [
                      SizedBox(
                        height: 220,
                        child: series.length < 2
                            ? Center(
                                child: Text(
                                  'Con 2 registros diarios verás aquí tu gráfica 📈',
                                  style: t.bodyMedium?.copyWith(color: FmColors.muted),
                                ),
                              )
                            : CustomPaint(
                                size: Size.infinite,
                                painter: MoodChartPainter(
                                  points: series,
                                  from: from,
                                  to: DateTime(now.year, now.month, now.day),
                                  trained: trained,
                                  labelStyle: t.labelSmall!.copyWith(color: FmColors.muted),
                                  grid: FmColors.line,
                                  moodColor: FmColors.primary,
                                ),
                              ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 14,
                        children: [
                          _legend(FmColors.primary, 'Ánimo'),
                          _legend(_energyColor, 'Energía'),
                          _legend(const Color(0xFFE5A54B), 'Día con entreno'),
                        ],
                      ),
                      if (weekly)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text('Cada punto es la media de una semana', style: t.labelSmall?.copyWith(color: FmColors.muted)),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (inRange.isNotEmpty)
                Row(
                  children: [
                    Expanded(child: _stat(_avg(inRange.map((c) => c.mood)), 'ánimo medio')),
                    const SizedBox(width: 10),
                    Expanded(child: _stat(_avg(inRange.map((c) => c.energy)), 'energía media')),
                    const SizedBox(width: 10),
                    Expanded(child: _stat(_avg(inRange.map((c) => c.sleep)), 'descanso medio')),
                  ],
                ),
              if (compare != null) ...[
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('💪 ¿Entrenar te sube el ánimo?', style: t.titleSmall),
                        const SizedBox(height: 6),
                        Text(
                          'Días con entreno: ${_n(compare.$1)} · sin entreno: ${_n(compare.$2)}',
                          style: t.bodyMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          compare.$1 - compare.$2 >= 0.3
                              ? 'Los días que entrenas te sientes mejor. ¡Tu cuerpo te lo agradece!'
                              : compare.$2 - compare.$1 >= 0.3
                                  ? 'Los días de entreno te sientes algo más baja. Quizá te venga bien más descanso o entrenos más suaves.'
                                  : 'Tu ánimo es parecido entrenes o no.',
                          style: t.bodySmall?.copyWith(color: FmColors.muted),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              if (best != null) ...[
                const SizedBox(height: 4),
                Card(
                  child: ListTile(
                    leading: const Text('🌟', style: TextStyle(fontSize: 24)),
                    title: Text('Tu mejor día suele ser el ${weekdayNames[best - 1]}'),
                    subtitle: const Text('Según tu ánimo medio de cada día de la semana'),
                  ),
                ),
              ],
              if (recent.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Últimos registros', style: t.titleMedium),
                const SizedBox(height: 6),
                for (final c in recent.take(10))
                  Card(
                    child: ListTile(
                      leading: Text(_faces[(c.mood - 1).clamp(0, 4)], style: const TextStyle(fontSize: 26)),
                      title: Text(formatLongDate(c.date)),
                      subtitle: Text([
                        'Ánimo ${c.mood}/5 · energía ${c.energy}/5 · descanso ${c.sleep}/5',
                        if (c.comment.trim().isNotEmpty) '“${c.comment.trim()}”',
                      ].join('\n')),
                    ),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }

  static String _n(double v) => v.toStringAsFixed(1).replaceAll('.', ',');
  static double _avg(Iterable<int> v) => v.isEmpty ? 0 : v.reduce((a, b) => a + b) / v.length;

  Widget _legend(Color c, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 12, height: 12, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      );

  Widget _stat(double v, String label) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(color: FmColors.lavender, borderRadius: BorderRadius.circular(14)),
      child: Column(
        children: [
          Text('${_faces[(v.round() - 1).clamp(0, 4)]} ${_n(v)}', style: t.titleMedium?.copyWith(color: FmColors.ink)),
          Text(label, style: t.labelSmall?.copyWith(color: FmColors.ink)),
        ],
      ),
    );
  }
}

/// Dos líneas (ánimo y energía) en escala 1–5, con marcas de los días de entreno abajo.
class MoodChartPainter extends CustomPainter {
  MoodChartPainter({
    required this.points,
    required this.from,
    required this.to,
    required this.trained,
    required this.labelStyle,
    required this.grid,
    required this.moodColor,
  });

  final List<MoodPoint> points;
  final DateTime from;
  final DateTime to;
  final Set<DateTime> trained;
  final TextStyle labelStyle;
  final Color grid;
  final Color moodColor;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 30.0, right = 6.0, top = 8.0, bottom = 34.0;
    final w = size.width - left - right;
    final h = size.height - top - bottom;
    final span = to.difference(from).inHours / 24;
    double x(DateTime d) => left + w * ((d.difference(from).inHours / 24) / (span <= 0 ? 1 : span)).clamp(0.0, 1.0);
    double y(double v) => top + h * (1 - (v - 1) / 4);

    final gridP = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var v = 1; v <= 5; v++) {
      canvas.drawLine(Offset(left, y(v.toDouble())), Offset(left + w, y(v.toDouble())), gridP);
      final tp = TextPainter(
        text: TextSpan(text: _faces[v - 1], style: const TextStyle(fontSize: 12)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(2, y(v.toDouble()) - tp.height / 2));
    }

    // Días de entreno: marcas en una franja inferior.
    final mark = Paint()..color = const Color(0xFFE5A54B);
    final markY = top + h + 10;
    for (final d in trained) {
      if (d.isBefore(from) || d.isAfter(to.add(const Duration(days: 1)))) continue;
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(x(d), markY), width: 4, height: 8), const Radius.circular(2)),
        mark,
      );
    }

    void line(double Function(MoodPoint) v, Color c, {bool area = false}) {
      final path = Path();
      for (final (i, p) in points.indexed) {
        final o = Offset(x(p.date), y(v(p)));
        if (i == 0) {
          path.moveTo(o.dx, o.dy);
        } else {
          // Curva suave entre puntos.
          final prev = points[i - 1];
          final po = Offset(x(prev.date), y(v(prev)));
          final mx = (po.dx + o.dx) / 2;
          path.cubicTo(mx, po.dy, mx, o.dy, o.dx, o.dy);
        }
      }
      if (area) {
        final fill = Path.from(path)
          ..lineTo(x(points.last.date), top + h)
          ..lineTo(x(points.first.date), top + h)
          ..close();
        canvas.drawPath(
          fill,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [c.withValues(alpha: 0.25), c.withValues(alpha: 0)],
            ).createShader(Rect.fromLTWH(left, top, w, h)),
        );
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = c
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round,
      );
      for (final p in points) {
        canvas.drawCircle(Offset(x(p.date), y(v(p))), 3, Paint()..color = c);
      }
    }

    line((p) => p.energy, _energyColor);
    line((p) => p.mood, moodColor, area: true);

    for (final (d, align) in [(from, 0.0), (to, 1.0)]) {
      final tp = TextPainter(text: TextSpan(text: formatShortDate(d), style: labelStyle), textDirection: TextDirection.ltr)
        ..layout();
      tp.paint(canvas, Offset(left + (w - tp.width) * align, size.height - tp.height));
    }
  }

  @override
  bool shouldRepaint(MoodChartPainter o) => o.points != points || o.trained != trained;
}
