import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Ilustración de una persona de perfil (mirando a la derecha) en cualquier postura.
/// Se usa en la rutina matutina (hipopresivos) y en los ejercicios de boxeo.
/// Todo está dibujado en código: no necesita imágenes y se puede animar entre posturas.

/// Postura: ángulos en grados. En piernas, 0 = vertical hacia abajo y positivo = hacia delante.
/// En brazos, el ángulo es respecto al tronco: 0 = colgando, 90 = al frente, 180 = arriba.
class FigurePose {
  const FigurePose({
    this.lean = 0,
    this.frontThigh = 4,
    this.frontShin = -4,
    this.backThigh = 4,
    this.backShin = -4,
    this.frontShoulder = 12,
    this.frontElbow = 8,
    this.backShoulder = 12,
    this.backElbow = 8,
    this.handsOnThighs = false,
    this.headTilt = 0,
  });

  /// Inclinación del tronco hacia delante.
  final double lean;
  final double frontThigh, frontShin, backThigh, backShin;
  final double frontShoulder, frontElbow, backShoulder, backElbow;
  final bool handsOnThighs;

  /// Barbilla hacia abajo (positivo).
  final double headTilt;

  /// Las dos piernas con la misma flexión de rodillas.
  const FigurePose.standing({
    double lean = 0,
    double knees = 10,
    double shoulder = 12,
    double elbow = 8,
    bool handsOnThighs = false,
  }) : this(
          lean: lean,
          frontThigh: knees * 0.55,
          frontShin: -knees * 0.45,
          backThigh: knees * 0.55 - 3,
          backShin: -knees * 0.45 - 3,
          frontShoulder: shoulder,
          frontElbow: elbow,
          backShoulder: shoulder,
          backElbow: elbow,
          handsOnThighs: handsOnThighs,
        );

  FigurePose lerp(FigurePose o, double t) {
    double l(double a, double b) => a + (b - a) * t;
    return FigurePose(
      lean: l(lean, o.lean),
      frontThigh: l(frontThigh, o.frontThigh),
      frontShin: l(frontShin, o.frontShin),
      backThigh: l(backThigh, o.backThigh),
      backShin: l(backShin, o.backShin),
      frontShoulder: l(frontShoulder, o.frontShoulder),
      frontElbow: l(frontElbow, o.frontElbow),
      backShoulder: l(backShoulder, o.backShoulder),
      backElbow: l(backElbow, o.backElbow),
      handsOnThighs: t < 0.5 ? handsOnThighs : o.handsOnThighs,
      headTilt: l(headTilt, o.headTilt),
    );
  }
}

enum FigureHair { ponytail, bun, short }

/// Posturas de boxeo (guardia de diestra: pierna y mano izquierdas delante).
abstract final class BoxingPoses {
  static const guard = FigurePose(
    lean: 6,
    frontThigh: 16,
    frontShin: 4,
    backThigh: -12,
    backShin: -20,
    frontShoulder: 38,
    frontElbow: 118,
    backShoulder: 26,
    backElbow: 128,
    headTilt: 8,
  );
  static const guardStep = FigurePose(
    lean: 6,
    frontThigh: 22,
    frontShin: 8,
    backThigh: -6,
    backShin: -14,
    frontShoulder: 38,
    frontElbow: 118,
    backShoulder: 26,
    backElbow: 128,
    headTilt: 8,
  );
  static const jab = FigurePose(
    lean: 10,
    frontThigh: 18,
    frontShin: 4,
    backThigh: -14,
    backShin: -22,
    frontShoulder: 86,
    frontElbow: 4,
    backShoulder: 26,
    backElbow: 128,
    headTilt: 8,
  );
  static const cross = FigurePose(
    lean: 16,
    frontThigh: 20,
    frontShin: 2,
    backThigh: -8,
    backShin: -16,
    frontShoulder: 34,
    frontElbow: 122,
    backShoulder: 88,
    backElbow: 2,
    headTilt: 8,
  );
  static const hook = FigurePose(
    lean: 10,
    frontThigh: 18,
    frontShin: 4,
    backThigh: -12,
    backShin: -20,
    frontShoulder: 84,
    frontElbow: 70,
    backShoulder: 26,
    backElbow: 128,
    headTilt: 8,
  );
  static const uppercut = FigurePose(
    lean: 12,
    frontThigh: 26,
    frontShin: 0,
    backThigh: -10,
    backShin: -26,
    frontShoulder: 38,
    frontElbow: 118,
    backShoulder: 40,
    backElbow: 120,
    headTilt: 8,
  );
  static const slip = FigurePose(
    lean: 26,
    frontThigh: 30,
    frontShin: 2,
    backThigh: -6,
    backShin: -26,
    frontShoulder: 40,
    frontElbow: 118,
    backShoulder: 28,
    backElbow: 128,
    headTilt: 12,
  );

  static const all = <String, FigurePose>{
    'guardia': guard,
    'guardia_paso': guardStep,
    'jab': jab,
    'directo': cross,
    'gancho': hook,
    'uppercut': uppercut,
    'esquiva': slip,
  };
}

/// Colores de la figura (estilo de la app).
class _Palette {
  const _Palette(this.dark);
  final bool dark;
  Color get skin => const Color(0xFFD9C7F5);
  Color get skinBack => const Color(0xFFB9A2E6);
  Color get top => const Color(0xFF7041B8);
  Color get legs => const Color(0xFF3F2768);
  Color get legsBack => const Color(0xFF2F1D50);
  Color get hair => const Color(0xFF2B1B43);
  Color get shoe => const Color(0xFFF7F3FF);
  Color get shoeSole => const Color(0xFF9468E0);
  Color get glove => const Color(0xFFE5484D);
  Color get gloveBack => const Color(0xFFB8333A);
}

class BodyFigurePainter extends CustomPainter {
  BodyFigurePainter({
    required this.pose,
    this.chest = 0,
    this.belly = 0,
    this.ribs = 0,
    this.air = 0,
    this.anim = 0,
    this.cues = false,
    this.wall = false,
    this.gloves = false,
    this.hair = FigureHair.ponytail,
    this.dark = false,
    this.scene = true,
  });

  final FigurePose pose;

  /// Respiración: pecho, abdomen (+ fuera, − dentro) y costillas abiertas.
  final double chest, belly, ribs;

  /// 1 = entra aire, −1 = sale, 0 = nada.
  final int air;

  /// 0…1 repetido (para mover aire y flechas).
  final double anim;

  /// Flechas de la apnea: crecer y meter el ombligo.
  final bool cues;
  final bool wall;
  final bool gloves;
  final FigureHair hair;
  final bool dark;

  /// Fondo suave (sol y suelo).
  final bool scene;

  static double _rad(double d) => d * math.pi / 180;

  /// Una extremidad redondeada que se afina de [ra] a [rb].
  static void _limb(Canvas c, Offset a, Offset b, double ra, double rb, Paint p) {
    final d = b - a;
    final len = d.distance;
    if (len < 0.01) {
      c.drawCircle(a, math.max(ra, rb), p);
      return;
    }
    final u = d / len;
    final n = Offset(-u.dy, u.dx);
    c.drawPath(
      Path()
        ..moveTo((a + n * ra).dx, (a + n * ra).dy)
        ..lineTo((b + n * rb).dx, (b + n * rb).dy)
        ..lineTo((b - n * rb).dx, (b - n * rb).dy)
        ..lineTo((a - n * ra).dx, (a - n * ra).dy)
        ..close(),
      p,
    );
    c.drawCircle(a, ra, p);
    c.drawCircle(b, rb, p);
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
  void paint(Canvas canvas, Size size) {
    final col = _Palette(dark);
    final h = size.height * 0.76;
    final thigh = 0.232 * h, shin = 0.232 * h, foot = 0.07 * h;
    final upperArm = 0.16 * h, foreArm = 0.145 * h;
    final trunk = 0.335 * h;

    // 1) Piernas desde la cadera en (0, 0).
    (Offset, Offset) leg(double th, double sh) {
      final knee = Offset(math.sin(_rad(th)) * thigh, math.cos(_rad(th)) * thigh);
      final ankle = knee + Offset(math.sin(_rad(sh)) * shin, math.cos(_rad(sh)) * shin);
      return (knee, ankle);
    }

    var (fKnee, fAnkle) = leg(pose.frontThigh, pose.frontShin);
    var (bKnee, bAnkle) = leg(pose.backThigh, pose.backShin);

    // 2) Colocar: los pies sobre el suelo y centrados.
    final ground = size.height * 0.92;
    final lowest = math.max(fAnkle.dy, bAnkle.dy);
    final midX = (fAnkle.dx + bAnkle.dx) / 2;
    final origin = Offset(size.width * 0.47 - midX, ground - 0.035 * h - lowest);
    final hip = origin;
    fKnee += origin;
    fAnkle += origin;
    bKnee += origin;
    bAnkle += origin;

    // Tronco.
    final lean = _rad(pose.lean);
    final up = Offset(math.sin(lean), -math.cos(lean));
    final fwd = Offset(math.cos(lean), math.sin(lean));
    Offset at(double u, double v) => hip + up * (u * trunk) + fwd * (v * h);

    // ---------------- fondo
    if (scene) {
      final sun = Offset(size.width * 0.5, size.height * 0.45);
      canvas.drawCircle(
        sun,
        size.height * 0.42,
        Paint()
          ..shader = RadialGradient(
            colors: [
              (dark ? const Color(0xFF4A2F7D) : const Color(0xFFFFE6C9)).withValues(alpha: dark ? 0.55 : 0.9),
              (dark ? const Color(0xFF2B1B43) : const Color(0xFFF1EAFD)).withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: sun, radius: size.height * 0.42)),
      );
    }
    if (wall) {
      final wx = at(0.15, -0.085).dx;
      canvas.drawRRect(
        RRect.fromRectAndCorners(Rect.fromLTRB(0, 0, wx, ground), topRight: const Radius.circular(6)),
        Paint()..color = dark ? const Color(0xFF2A2140) : const Color(0xFFE6DDF5),
      );
    }
    canvas.drawLine(
      Offset(size.width * 0.1, ground),
      Offset(size.width * 0.9, ground),
      Paint()
        ..color = (dark ? Colors.white : const Color(0xFF7041B8)).withValues(alpha: 0.18)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset((fAnkle.dx + bAnkle.dx) / 2 + 0.03 * h, ground), width: 0.36 * h, height: 0.03 * h),
      Paint()..color = Colors.black.withValues(alpha: 0.12),
    );

    Paint fill(Color c) => Paint()
      ..color = c
      ..isAntiAlias = true;

    // ---------------- brazos (posiciones)
    final shoulder = at(0.88, -0.005);
    Offset armDir(double deg) {
      final a = _rad(deg);
      return -up * math.cos(a) + fwd * math.sin(a);
    }

    (Offset, Offset) arm(double sh, double el, {required bool onThigh, required Offset knee}) {
      if (onThigh) {
        final wrist = Offset.lerp(hip, knee, 0.68)! + Offset(0.01 * h, -0.025 * h);
        final mid = Offset.lerp(shoulder, wrist, 0.5)!;
        return (mid - fwd * (0.025 * h), wrist);
      }
      final elbow = shoulder + armDir(sh) * upperArm;
      return (elbow, elbow + armDir(sh + el) * foreArm);
    }

    final (bElbow, bWrist) = arm(pose.backShoulder, pose.backElbow, onThigh: pose.handsOnThighs, knee: bKnee);
    final (fElbow, fWrist) = arm(pose.frontShoulder, pose.frontElbow, onThigh: pose.handsOnThighs, knee: fKnee);
    final backShift = fwd * (-0.018 * h);

    void drawLeg(Offset knee, Offset ankle, Color legging, Color shoe) {
      _limb(canvas, hip + fwd * (0.0 * h), knee, 0.058 * h, 0.035 * h, fill(legging));
      _limb(canvas, knee, ankle, 0.034 * h, 0.024 * h, fill(legging));
      // Zapatilla
      final toe = ankle + Offset(foot, 0.012 * h);
      _limb(canvas, ankle + Offset(-0.012 * h, 0.012 * h), toe, 0.026 * h, 0.02 * h, fill(shoe));
      canvas.drawLine(
        ankle + Offset(-0.03 * h, 0.034 * h),
        toe + Offset(0.012 * h, 0.018 * h),
        Paint()
          ..color = col.shoeSole
          ..strokeWidth = 0.012 * h
          ..strokeCap = StrokeCap.round,
      );
    }

    void drawArm(Offset elbow, Offset wrist, Color skin, Color glove, Offset shift) {
      final s = shoulder + shift;
      _limb(canvas, s, elbow + shift, 0.03 * h, 0.023 * h, fill(skin));
      _limb(canvas, elbow + shift, wrist + shift, 0.023 * h, 0.019 * h, fill(skin));
      if (gloves) {
        final g = wrist + shift + (wrist - elbow) / (wrist - elbow).distance * (0.02 * h);
        canvas.drawCircle(g, 0.045 * h, fill(glove));
        canvas.drawCircle(g + Offset(-0.012 * h, -0.014 * h), 0.014 * h, Paint()..color = Colors.white.withValues(alpha: 0.35));
        // Puño de la manga del guante
        _limb(canvas, wrist + shift - (wrist - elbow) / (wrist - elbow).distance * (0.01 * h), g, 0.024 * h, 0.03 * h, fill(glove));
      } else {
        canvas.drawCircle(wrist + shift + (wrist - elbow) / (wrist - elbow).distance * (0.018 * h), 0.022 * h, fill(skin));
      }
    }

    // ---------------- lado lejano
    drawLeg(bKnee + backShift, bAnkle + backShift, col.legsBack, col.shoe.withValues(alpha: 1));
    drawArm(bElbow, bWrist, col.skinBack, col.gloveBack, backShift);

    // ---------------- tronco con respiración
    final c = chest, b = belly, r = ribs;
    final front = <Offset>[
      at(-0.05, 0.064),
      at(0.12, 0.072 + 0.010 * b),
      at(0.30, 0.076 + 0.026 * b),
      at(0.46, 0.072 + 0.014 * b + 0.006 * r),
      at(0.62, 0.08 + 0.004 * b + 0.018 * r + 0.006 * c),
      at(0.78, 0.092 + 0.014 * c + 0.008 * r),
      at(0.93, 0.058),
    ];
    final back = <Offset>[
      at(1.0, -0.044),
      at(0.84, -0.064),
      at(0.62, -0.058 - 0.004 * r),
      at(0.4, -0.05),
      at(0.18, -0.074),
      at(0.0, -0.09),
      at(-0.12, -0.058),
    ];
    final torso = _smooth([...front, ...back]);
    canvas.drawPath(torso, fill(col.skin));
    canvas.save();
    canvas.clipPath(torso);
    // Top deportivo (pecho) y mallas (cadera): el abdomen queda a la vista para ver la respiración.
    final topBand = Path()
      ..addPolygon([at(0.6, -0.3), at(0.6, 0.3), at(1.2, 0.3), at(1.2, -0.3)], true);
    canvas.drawPath(topBand, fill(col.top));
    canvas.drawPath(Path()..addPolygon([at(0.6, -0.3), at(0.6, 0.3), at(0.63, 0.3), at(0.63, -0.3)], true),
        fill(Colors.white.withValues(alpha: 0.35)));
    final waist = Path()..addPolygon([at(-0.4, -0.3), at(-0.4, 0.3), at(0.14, 0.3), at(0.14, -0.3)], true);
    canvas.drawPath(waist, fill(col.legs));
    canvas.restore();

    // ---------------- lado cercano
    drawLeg(fKnee, fAnkle, col.legs, col.shoe);

    // Cuello y cabeza
    final neckBase = at(0.94, 0.005);
    final headR = 0.06 * h;
    final tilt = _rad(pose.headTilt);
    final hUp = Offset(math.sin(lean + tilt * 0.5), -math.cos(lean + tilt * 0.5));
    final hFwd = Offset(-hUp.dy, hUp.dx);
    final head = neckBase + hUp * (0.075 * h) + hFwd * (0.012 * h);
    _limb(canvas, neckBase, head - hUp * (0.02 * h), 0.022 * h, 0.02 * h, fill(col.skin));

    final hairP = fill(col.hair);
    switch (hair) {
      case FigureHair.ponytail:
        final tail = Path()
          ..moveTo((head - hFwd * (headR * 0.7) - hUp * (headR * 0.1)).dx, (head - hFwd * (headR * 0.7) - hUp * (headR * 0.1)).dy);
        final tip = head - hFwd * (headR * 1.75) - hUp * (headR * 1.15);
        final ctrl = head - hFwd * (headR * 2.0) + hUp * (headR * 0.15);
        final back2 = head - hFwd * (headR * 0.75) + hUp * (headR * 0.55);
        tail
          ..quadraticBezierTo(ctrl.dx, ctrl.dy, tip.dx, tip.dy)
          ..quadraticBezierTo((head - hFwd * (headR * 1.2) - hUp * (headR * 0.2)).dx,
              (head - hFwd * (headR * 1.2) - hUp * (headR * 0.2)).dy, back2.dx, back2.dy)
          ..close();
        canvas.drawPath(tail, hairP);
      case FigureHair.bun:
        canvas.drawCircle(head - hFwd * (headR * 0.75) + hUp * (headR * 0.8), headR * 0.45, hairP);
      case FigureHair.short:
        break;
    }
    canvas.drawCircle(head - hFwd * (headR * 0.14) + hUp * (headR * 0.08), headR * 1.04, hairP);
    // Cara
    canvas.drawCircle(head + hFwd * (headR * 0.1) - hUp * (headR * 0.06), headR * 0.9, fill(col.skin));
    // Flequillo / línea del pelo
    canvas.drawArc(
      Rect.fromCircle(center: head - hFwd * (headR * 0.14) + hUp * (headR * 0.08), radius: headR * 1.04),
      math.atan2(hUp.dy, hUp.dx) - 0.15,
      0.95,
      true,
      hairP,
    );
    // Nariz y oreja
    canvas.drawCircle(head + hFwd * (headR * 0.98) - hUp * (headR * 0.12), headR * 0.16, fill(col.skin));
    canvas.drawCircle(head - hFwd * (headR * 0.08) - hUp * (headR * 0.1), headR * 0.16, fill(col.skinBack));
    // Ojo cerrado (tranquila) y mejilla
    final eye = head + hFwd * (headR * 0.55) + hUp * (headR * 0.08);
    canvas.drawArc(Rect.fromCenter(center: eye, width: headR * 0.32, height: headR * 0.2), 0, math.pi, false,
        Paint()
          ..color = col.hair
          ..style = PaintingStyle.stroke
          ..strokeWidth = headR * 0.08
          ..strokeCap = StrokeCap.round);
    canvas.drawCircle(head + hFwd * (headR * 0.45) - hUp * (headR * 0.3), headR * 0.14,
        Paint()..color = const Color(0xFFF4A6C8).withValues(alpha: 0.7));

    drawArm(fElbow, fWrist, col.skin, col.glove, Offset.zero);

    // ---------------- aire
    if (air != 0) {
      final nose = head + hFwd * (headR * 1.1) - hUp * (headR * 0.12);
      for (var i = 0; i < 5; i++) {
        var f = (anim * 1.4 + i / 5) % 1.0;
        if (air > 0) f = 1 - f;
        final p = nose + hFwd * (headR * (0.4 + 2.4 * f)) + hUp * (headR * (math.sin(f * 6 + i) * 0.25));
        canvas.drawCircle(
          p,
          headR * (0.08 + 0.1 * (air > 0 ? f : 1 - f)),
          Paint()..color = const Color(0xFF7FC8E8).withValues(alpha: (0.85 * (air > 0 ? 1 - f * 0.6 : 1 - f)).clamp(0.1, 1.0)),
        );
      }
    }

    // ---------------- apnea: crecer y ombligo adentro
    if (cues) {
      final pulse = 0.5 + 0.5 * math.sin(anim * 2 * math.pi);
      final cue = Paint()
        ..color = const Color(0xFF3FBF9F).withValues(alpha: 0.65 + 0.35 * pulse)
        ..strokeWidth = 0.014 * h
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      final top = head + hUp * (headR * 1.5);
      _arrow(canvas, top, top + hUp * (0.075 * h + 0.015 * h * pulse), cue);
      final navel = at(0.3, 0.07 + 0.026 * b);
      _arrow(canvas, navel + fwd * (0.12 * h), navel + fwd * (0.03 * h + 0.012 * h * (1 - pulse)), cue);
      // Costillas que se abren: brillo suave en el costado
      canvas.drawOval(
        Rect.fromCenter(center: at(0.66, 0.0), width: 0.11 * h, height: 0.13 * h),
        Paint()
          ..color = const Color(0xFF3FBF9F).withValues(alpha: 0.18 + 0.12 * pulse)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
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

  @override
  bool shouldRepaint(BodyFigurePainter o) => true;
}

/// Animación de un golpe o movimiento: postura inicial → final → vuelta.
class FigureMoveAnimation extends StatefulWidget {
  const FigureMoveAnimation({
    super.key,
    required this.start,
    required this.end,
    this.gloves = true,
    this.hair = FigureHair.ponytail,
    this.duration = const Duration(milliseconds: 1600),
  });

  final FigurePose start;
  final FigurePose end;
  final bool gloves;
  final FigureHair hair;
  final Duration duration;

  @override
  State<FigureMoveAnimation> createState() => _FigureMoveAnimationState();
}

class _FigureMoveAnimationState extends State<FigureMoveAnimation> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.duration)..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// Golpe rápido y vuelta controlada a la guardia.
  static double _p(double t) {
    if (t < 0.35) return 0;
    if (t < 0.5) return Curves.easeOutCubic.transform((t - 0.35) / 0.15);
    if (t < 0.62) return 1;
    if (t < 0.85) return 1 - Curves.easeInOut.transform((t - 0.62) / 0.23);
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) => CustomPaint(
        size: Size.infinite,
        painter: BodyFigurePainter(
          pose: reduce ? widget.end : widget.start.lerp(widget.end, _p(_c.value)),
          gloves: widget.gloves,
          hair: widget.hair,
          dark: dark,
        ),
      ),
    );
  }
}

/// Postura a partir de `figure:id` (o null si no es una ilustración).
FigurePose? figurePoseOf(String? src) =>
    src != null && src.startsWith('figure:') ? BoxingPoses.all[src.substring(7)] : null;

/// Miniatura fija de una ilustración (en listas).
class FigureThumb extends StatelessWidget {
  const FigureThumb({super.key, required this.src});
  final String src;

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: const Color(0xFFEDE4FB),
        child: CustomPaint(
          size: Size.infinite,
          painter: BodyFigurePainter(pose: figurePoseOf(src) ?? BoxingPoses.guard, gloves: true, scene: false),
        ),
      );
}
