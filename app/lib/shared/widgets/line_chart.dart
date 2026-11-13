import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';

/// Gráfica de línea simple para la evolución de una medida en el tiempo.
class SimpleLineChart extends StatelessWidget {
  const SimpleLineChart({
    super.key,
    required this.points,
    this.height = 180,
    this.unit = '',
    this.target,
  });

  final List<(DateTime, double)> points;
  final double height;
  final String unit;

  /// Línea de meta opcional.
  final double? target;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    if (points.length < 2) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            points.isEmpty ? 'Aún no hay datos' : 'Con 2 registros verás la gráfica',
            style: t.bodyMedium?.copyWith(color: FmColors.muted),
          ),
        ),
      );
    }
    return Semantics(
      label: 'Gráfica: de ${_f(points.first.$2)} a ${_f(points.last.$2)} $unit',
      child: SizedBox(
        height: height,
        child: CustomPaint(
          painter: _ChartPainter(points: points, target: target, labelStyle: t.labelSmall!),
          size: Size.infinite,
        ),
      ),
    );
  }
}

String _f(double v) => v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);

class _ChartPainter extends CustomPainter {
  _ChartPainter({required this.points, required this.target, required this.labelStyle});
  final List<(DateTime, double)> points;
  final double? target;
  final TextStyle labelStyle;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 36.0, bottom = 22.0, top = 10.0, right = 8.0;
    final w = size.width - left - right;
    final h = size.height - top - bottom;
    final values = [for (final p in points) p.$2, ?target];
    var minV = values.reduce((a, b) => a < b ? a : b);
    var maxV = values.reduce((a, b) => a > b ? a : b);
    final pad = ((maxV - minV) * 0.15).clamp(0.5, double.infinity);
    minV -= pad;
    maxV += pad;
    final t0 = points.first.$1.millisecondsSinceEpoch.toDouble();
    final t1 = points.last.$1.millisecondsSinceEpoch.toDouble();
    Offset pos(DateTime d, double v) => Offset(
          left + (t1 == t0 ? w / 2 : (d.millisecondsSinceEpoch - t0) / (t1 - t0) * w),
          top + (1 - (v - minV) / (maxV - minV)) * h,
        );

    // Rejilla y etiquetas Y
    final grid = Paint()
      ..color = FmColors.line
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final v = minV + (maxV - minV) * i / 3;
      final y = top + (1 - i / 3) * h;
      canvas.drawLine(Offset(left, y), Offset(size.width - right, y), grid);
      _text(canvas, _f(v), Offset(0, y - 7), FmColors.muted);
    }
    // Fechas
    _text(canvas, formatShortDate(points.first.$1), Offset(left, size.height - 16), FmColors.muted);
    final lastLabel = formatShortDate(points.last.$1);
    _text(canvas, lastLabel, Offset(size.width - right - lastLabel.length * 6.2, size.height - 16), FmColors.muted);

    // Meta
    if (target != null) {
      final y = pos(points.first.$1, target!).dy;
      final dash = Paint()
        ..color = FmColors.mint
        ..strokeWidth = 2;
      for (var x = left; x < size.width - right; x += 10) {
        canvas.drawLine(Offset(x, y), Offset(x + 5, y), dash);
      }
      _text(canvas, 'meta', Offset(size.width - right - 30, y - 16), const Color(0xFF2E9E8F));
    }

    // Área y línea
    final path = Path();
    final area = Path()..moveTo(pos(points.first.$1, points.first.$2).dx, top + h);
    for (final (i, p) in points.indexed) {
      final o = pos(p.$1, p.$2);
      i == 0 ? path.moveTo(o.dx, o.dy) : path.lineTo(o.dx, o.dy);
      area.lineTo(o.dx, o.dy);
    }
    area
      ..lineTo(pos(points.last.$1, points.last.$2).dx, top + h)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [FmColors.primary.withValues(alpha: 0.22), FmColors.primary.withValues(alpha: 0.0)],
        ).createShader(Rect.fromLTWH(left, top, w, h)),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = FmColors.primary
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
    for (final p in points) {
      final o = pos(p.$1, p.$2);
      canvas.drawCircle(o, 4.5, Paint()..color = FmColors.surface);
      canvas.drawCircle(
          o,
          4.5,
          Paint()
            ..color = FmColors.primary
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5);
    }
  }

  void _text(Canvas c, String s, Offset at, Color color) {
    final tp = TextPainter(text: TextSpan(text: s, style: labelStyle.copyWith(color: color)), textDirection: TextDirection.ltr)
      ..layout();
    tp.paint(c, at);
  }

  @override
  bool shouldRepaint(_ChartPainter old) => old.points != points || old.target != target;
}
