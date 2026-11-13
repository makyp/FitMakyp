import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../domain/hypopressive.dart';

/// Figura de perfil (mirando a la derecha) que hace la postura y "respira":
/// el pecho y el abdomen cambian con [shape] y unas flechas muestran el aire.
class HypoFigurePainter extends CustomPainter {
  HypoFigurePainter({
    required this.pose,
    this.shape = BreathShape.rest,
    this.air = 0,
    this.anim = 0,
    this.cues = false,
    this.dark = false,
    this.bun = true,
  });

  final PoseSpec pose;
  final BreathShape shape;

  /// 1 = entra aire (inhala), −1 = sale (exhala), 0 = nada.
  final int air;

  /// 0…1 repetido, para mover flechas.
  final double anim;

  /// Flechas de apnea: crecer y ombligo adentro.
  final bool cues;
  final bool dark;

  /// Moño en el pelo (no se dibuja para hombres).
  final bool bun;

  static const _body = Color(0xFF7041B8);
  static const _limb = Color(0xFF9468E0);
  static const _backLimb = Color(0xFFC3ABEE);
  static const _head = Color(0xFF9468E0);
  static const _mint = Color(0xFF3FBF9F);
  static const _air = Color(0xFF4FB3D9);

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height * 0.74;
    final ground = size.height * 0.93;
    double rad(double d) => d * math.pi / 180;

    // Piernas: el tobillo fijo; la cadera retrocede al flexionar rodillas.
    final k = rad(pose.knees);
    final shin = 0.245 * h, thigh = 0.25 * h;
    final ankle = Offset(size.width * 0.47, ground - 0.02 * h);
    final knee = ankle + Offset(math.sin(k * 0.75) * shin, -math.cos(k * 0.75) * shin);
    final hip = knee + Offset(-math.sin(k * 1.05) * thigh, -math.cos(k * 1.05) * thigh);

    // Tronco: ejes "arriba" y "adelante".
    final lean = rad(pose.lean);
    final up = Offset(math.sin(lean), -math.cos(lean));
    final fwd = Offset(math.cos(lean), math.sin(lean));
    final trunk = 0.31 * h;
    Offset at(double u, double v) => hip + up * (u * trunk) + fwd * (v * h);

    // Pared detrás de la espalda.
    if (pose.wall) {
      final wx = at(0.0, -0.08).dx - 1;
      canvas.drawRect(
        Rect.fromLTRB(0, 0, wx, ground),
        Paint()..color = (dark ? const Color(0xFF2A2140) : const Color(0xFFE9E2F5)),
      );
      canvas.drawLine(Offset(wx, 0), Offset(wx, ground), Paint()
        ..color = const Color(0xFFB9A8D6)
        ..strokeWidth = 2);
    }

    // Suelo y sombra.
    canvas.drawLine(
      Offset(size.width * 0.08, ground),
      Offset(size.width * 0.92, ground),
      Paint()
        ..color = const Color(0xFFB9A8D6)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(ankle.dx + 0.02 * h, ground), width: 0.32 * h, height: 0.035 * h),
      Paint()..color = const Color(0x22000000),
    );

    Paint limb(Color c, double w) => Paint()
      ..color = c
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    void leg(Color c, Offset shift) {
      final p = Path()
        ..moveTo(hip.dx + shift.dx, hip.dy + shift.dy)
        ..lineTo(knee.dx + shift.dx, knee.dy + shift.dy)
        ..lineTo(ankle.dx + shift.dx, ankle.dy + shift.dy)
        ..lineTo(ankle.dx + shift.dx + 0.075 * h, ankle.dy + shift.dy + 0.012 * h);
      canvas.drawPath(p, limb(c, 0.068 * h));
    }

    // Hombro y brazos.
    final shoulder = at(0.9, 0.0);
    final upperArm = 0.165 * h, foreArm = 0.15 * h;
    Offset armDir(double deg) {
      final a = rad(deg);
      return -up * math.cos(a) + fwd * math.sin(a);
    }

    late Offset elbow, wrist;
    if (pose.handsOnThighs) {
      wrist = Offset.lerp(hip, knee, 0.62)! + Offset(0.015 * h, -0.02 * h);
      final mid = Offset.lerp(shoulder, wrist, 0.5)!;
      elbow = mid + Offset(-0.02 * h, -0.01 * h);
    } else {
      elbow = shoulder + armDir(pose.shoulder) * upperArm;
      wrist = elbow + armDir(pose.shoulder + pose.elbow) * foreArm;
    }

    void arm(Color c, Offset shift) {
      final p = Path()
        ..moveTo(shoulder.dx + shift.dx, shoulder.dy + shift.dy)
        ..lineTo(elbow.dx + shift.dx, elbow.dy + shift.dy)
        ..lineTo(wrist.dx + shift.dx, wrist.dy + shift.dy);
      canvas.drawPath(p, limb(c, 0.044 * h));
      canvas.drawCircle(wrist + shift, 0.028 * h, Paint()..color = c);
    }

    // Lado lejano (detrás).
    leg(_backLimb, Offset(-0.025 * h, 0));
    arm(_backLimb, Offset(-0.03 * h, -0.005 * h));

    // Torso con respiración.
    final c = shape.chest, b = shape.belly, r = shape.ribs;
    final front = <Offset>[
      at(-0.02, 0.062),
      at(0.15, 0.070 + 0.012 * b),
      at(0.32, 0.074 + 0.026 * b),
      at(0.48, 0.070 + 0.014 * b + 0.006 * r),
      at(0.64, 0.074 + 0.004 * b + 0.018 * r + 0.006 * c),
      at(0.80, 0.082 + 0.012 * c + 0.008 * r),
      at(0.95, 0.05),
    ];
    final back = <Offset>[
      at(1.0, -0.04),
      at(0.85, -0.058),
      at(0.62, -0.056 - 0.004 * r),
      at(0.38, -0.05),
      at(0.16, -0.068),
      at(0.0, -0.078),
      at(-0.1, -0.045),
    ];
    final torso = _smooth([...front, ...back]);
    canvas.drawPath(
      torso,
      Paint()
        ..shader = LinearGradient(
          colors: const [Color(0xFF8A5CD6), _body],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(torso.getBounds()),
    );

    // Lado cercano.
    leg(_limb, Offset.zero);

    // Cuello y cabeza.
    final neckTop = at(1.08, 0.008);
    canvas.drawLine(at(0.95, 0.0), neckTop, limb(_limb, 0.05 * h));
    final headR = 0.062 * h;
    final head = neckTop + up * (headR * 0.85) + fwd * (0.012 * h);
    if (bun) canvas.drawCircle(head - fwd * (headR * 0.95) + up * (headR * 0.35), headR * 0.42, Paint()..color = _body);
    canvas.drawCircle(head, headR, Paint()..color = _head);
    final nose = head + fwd * (headR * 1.02) + up * (-headR * 0.05);
    canvas.drawCircle(nose, headR * 0.16, Paint()..color = _head);

    arm(_limb, Offset.zero);

    // Aire entrando o saliendo.
    if (air != 0) {
      final paint = limb(_air, 0.012 * h);
      for (var i = 0; i < 3; i++) {
        var f = (anim + i / 3) % 1.0;
        if (air > 0) f = 1 - f; // entra: de lejos hacia la nariz
        final p = nose + fwd * (headR * (0.5 + 2.2 * f)) + up * (headR * (0.1 - 0.4 * f));
        final dir = air > 0 ? -1.0 : 1.0;
        final o = Paint()
          ..color = _air.withValues(alpha: (1 - (air > 0 ? 1 - f : f)).clamp(0.15, 1.0))
          ..strokeWidth = paint.strokeWidth
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;
        final s = headR * 0.32;
        canvas.drawPath(
          Path()
            ..moveTo(p.dx - dir * s, p.dy - s)
            ..lineTo(p.dx, p.dy)
            ..lineTo(p.dx - dir * s, p.dy + s),
          o,
        );
      }
    }

    // Apnea: crece hacia arriba y ombligo adentro.
    if (cues) {
      final pulse = 0.5 + 0.5 * math.sin(anim * 2 * math.pi);
      final cue = limb(_mint.withValues(alpha: 0.6 + 0.4 * pulse), 0.016 * h);
      final top = head + up * (headR * 1.4);
      _arrow(canvas, top, top + up * (0.09 * h + 0.015 * h * pulse), cue);
      final belly = at(0.3, 0.07 + 0.02 * b);
      final from = belly + fwd * (0.13 * h);
      _arrow(canvas, from, belly + fwd * (0.03 * h + 0.012 * h * (1 - pulse)), cue);
    }
  }

  static void _arrow(Canvas canvas, Offset from, Offset to, Paint p) {
    canvas.drawLine(from, to, p);
    final d = to - from;
    final len = d.distance;
    if (len == 0) return;
    final u = d / len;
    final n = Offset(-u.dy, u.dx);
    final s = p.strokeWidth * 2.2;
    canvas.drawPath(
      Path()
        ..moveTo(to.dx - u.dx * s + n.dx * s, to.dy - u.dy * s + n.dy * s)
        ..lineTo(to.dx, to.dy)
        ..lineTo(to.dx - u.dx * s - n.dx * s, to.dy - u.dy * s - n.dy * s),
      p,
    );
  }

  static Path _smooth(List<Offset> pts) {
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

  @override
  bool shouldRepaint(HypoFigurePainter o) => true;
}
