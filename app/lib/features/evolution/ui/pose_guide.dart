import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/models/body.dart';
import '../domain/muscle_map.dart';
import 'body_map.dart';

/// Dónde va el cuerpo dentro de la foto (fracciones del alto): siempre igual,
/// así todas las fotos quedan a la misma escala y se pueden comparar.
const poseHeadTop = 0.08;
const poseFeet = 0.93;

/// Consejo para cada ángulo.
String poseTip(PhotoAngle a) => switch (a) {
      PhotoAngle.frontal => 'De frente, brazos un poco separados del cuerpo y mirando a la cámara.',
      PhotoAngle.lateral => 'De perfil (lado derecho a la cámara), brazos relajados a los lados.',
      PhotoAngle.posterior => 'De espaldas, brazos un poco separados y cabeza recta.',
    };

/// Perfil (mirando a la derecha) en unidades del alto del cuerpo: (x desde el centro, y desde la coronilla).
const _sideFront = <(double, double)>[
  (0.0, 0.0), (0.048, 0.012), (0.07, 0.042), (0.08, 0.072), (0.07, 0.098), (0.045, 0.118), //
  (0.03, 0.135), (0.034, 0.165), (0.07, 0.195), (0.098, 0.225), (0.088, 0.262), (0.058, 0.305),
  (0.062, 0.355), (0.066, 0.395), (0.058, 0.44), (0.06, 0.5), (0.05, 0.6), (0.042, 0.715),
  (0.04, 0.79), (0.03, 0.93), (0.088, 0.972), (0.09, 1.0),
];
const _sideBack = <(double, double)>[
  (-0.04, 1.0), (-0.038, 0.95), (-0.034, 0.87), (-0.052, 0.79), (-0.036, 0.715), (-0.05, 0.6), //
  (-0.075, 0.51), (-0.098, 0.455), (-0.082, 0.395), (-0.044, 0.32), (-0.05, 0.25), (-0.062, 0.2),
  (-0.04, 0.15), (-0.052, 0.115), (-0.068, 0.07), (-0.052, 0.022),
];

Path _smooth(List<Offset> pts) {
  // Catmull-Rom cerrada.
  final p = Path()..moveTo(pts[0].dx, pts[0].dy);
  final n = pts.length;
  for (var i = 0; i < n; i++) {
    final p0 = pts[(i - 1 + n) % n], p1 = pts[i], p2 = pts[(i + 1) % n], p3 = pts[(i + 2) % n];
    final c1 = p1 + (p2 - p0) / 6;
    final c2 = p2 - (p3 - p1) / 6;
    p.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
  }
  return p..close();
}

/// Silueta guía dentro de un rectángulo del tamaño de la foto.
Path poseOutline(Size size, PhotoAngle angle, Map<Measure, double> measures, double heightCm) {
  final top = size.height * poseHeadTop;
  final h = size.height * (poseFeet - poseHeadTop);
  if (angle == PhotoAngle.lateral) {
    final cx = size.width / 2;
    Offset at((double, double) q) => Offset(cx + q.$1 * h, top + q.$2 * h);
    final body = _smooth([for (final q in [..._sideFront, ..._sideBack]) at(q)]);
    // Brazo relajado delante del costado.
    final arm = RRect.fromRectAndRadius(
      Rect.fromLTRB(cx - 0.022 * h, top + 0.17 * h, cx + 0.018 * h, top + 0.48 * h),
      Radius.circular(0.02 * h),
    );
    return Path.combine(PathOperation.union, body, Path()..addRRect(arm));
  }
  // Frente / espalda: la misma figura del mapa muscular, hecha con tus medidas.
  final view = angle == PhotoAngle.posterior ? BodyView.espalda : BodyView.frente;
  final g = BodyGeometry(SilhouetteWidths(measures), Size(size.width, h), heightCm, view);
  final out = Path.combine(PathOperation.union, g.outline, g.hair);
  final bounds = out.getBounds();
  // Ajustar para que coronilla y pies caigan en las líneas guía.
  final scale = h / bounds.height;
  final m = Matrix4.identity()
    ..translateByDouble(size.width / 2, top, 0, 1)
    ..scaleByDouble(scale, scale, 1, 1)
    ..translateByDouble(-bounds.center.dx, -bounds.top, 0, 1);
  return out.transform(m.storage);
}

Path _dashed(Path src, double dash, double gap) {
  final out = Path();
  for (final ui.PathMetric m in src.computeMetrics()) {
    var d = 0.0;
    while (d < m.length) {
      out.addPath(m.extractPath(d, (d + dash).clamp(0, m.length)), Offset.zero);
      d += dash + gap;
    }
  }
  return out;
}

class PoseGuidePainter extends CustomPainter {
  PoseGuidePainter({
    required this.angle,
    required this.measures,
    required this.heightCm,
    this.mirror = false,
    this.showLines = true,
  });

  final PhotoAngle angle;
  final Map<Measure, double> measures;
  final double heightCm;

  /// Cámara frontal: la vista previa es un espejo.
  final bool mirror;
  final bool showLines;

  @override
  void paint(Canvas canvas, Size size) {
    var path = poseOutline(size, angle, measures, heightCm);
    if (mirror) {
      final m = Matrix4.identity()
        ..translateByDouble(size.width, 0, 0, 1)
        ..scaleByDouble(-1, 1, 1, 1);
      path = path.transform(m.storage);
    }
    canvas.drawPath(path, Paint()..color = Colors.white.withValues(alpha: 0.10));
    final dashed = _dashed(path, 10, 6);
    canvas.drawPath(
      dashed,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      dashed,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );

    if (!showLines) return;
    final line = Paint()
      ..color = const Color(0xFFDCCBFA)
      ..strokeWidth = 1.5;
    for (final (f, label) in [(poseHeadTop, 'Cabeza aquí'), (poseFeet, 'Pies aquí')]) {
      final y = size.height * f;
      canvas.drawLine(Offset(12, y), Offset(size.width - 12, y), line);
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(color: Color(0xFFDCCBFA), fontSize: 12, fontWeight: FontWeight.w700, shadows: [
            Shadow(blurRadius: 4, color: Colors.black),
          ]),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(16, f < 0.5 ? y + 4 : y - tp.height - 4));
    }
    // Eje central para centrarse.
    final cx = size.width / 2;
    final axis = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..strokeWidth = 1;
    canvas.drawPath(_dashed(Path()..moveTo(cx, size.height * poseHeadTop)..lineTo(cx, size.height * poseFeet), 6, 8), axis);
  }

  @override
  bool shouldRepaint(PoseGuidePainter old) =>
      old.angle != angle || old.mirror != mirror || old.heightCm != heightCm || old.showLines != showLines || old.measures != measures;
}
