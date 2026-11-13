import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../core/theme/app_theme.dart';
import '../../features/pet/domain/pet_items.dart';

enum PetMood {
  happy,
  resting,
  motivating,
  celebrating,
}

/// Cosas que la mascota hace cuando se lo pides (o la tocas).
enum PetAction {
  mimos('Mimos', '💜', '¡Me encantan tus mimos!'),
  entrenar('Entrenar', '💪', '¡Sentadillas conmigo! Una, dos, tres…'),
  bailar('Bailar', '💃', '¡A mover el cuerpo!'),
  agua('Agua', '💧', '¡Glu, glu! Hidratarse es clave.'),
  estirar('Estirarse', '🧘', 'Mmm… qué bien sienta estirar.'),
  voltereta('Voltereta', '🤸', '¡Mira lo que sé hacer!'),
  siesta('Siesta', '😴', 'Descansar también es entrenar…');

  const PetAction(this.label, this.emoji, this.phrase);
  final String label;
  final String emoji;
  final String phrase;
}

/// La mascota de la usuaria con lo que lleva puesto (lee la tienda desde AppScope).
class MyPet extends StatelessWidget {
  const MyPet({super.key, this.mood = PetMood.happy, this.size = 120});
  final PetMood mood;
  final double size;

  @override
  Widget build(BuildContext context) {
    final pet = AppScope.of(context).pet;
    return ListenableBuilder(
      listenable: pet,
      builder: (_, _) => PetAvatar(mood: mood, size: size, look: pet.look),
    );
  }
}

/// Mascota dibujada en código (sin imágenes), con accesorios.
class PetAvatar extends StatefulWidget {
  const PetAvatar({
    super.key,
    this.mood = PetMood.happy,
    this.size = 120,
    this.look = const PetLook(),
    this.action,
    this.actionT = 0,
  });

  final PetMood mood;
  final double size;
  final PetLook look;

  /// Acción en curso y su avance (0…1).
  final PetAction? action;
  final double actionT;

  @override
  State<PetAvatar> createState() => _PetAvatarState();
}

class _PetAvatarState extends State<PetAvatar> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: widget.mood == PetMood.resting ? 3200 : 1600),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Mascota ${_moodLabel(widget.mood)}',
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = Curves.easeInOut.transform(_c.value);
          final a = widget.action;
          final at = widget.actionT;
          final mood = switch (a) {
            null => widget.mood,
            PetAction.siesta => PetMood.resting,
            PetAction.entrenar => PetMood.motivating,
            PetAction.agua || PetAction.estirar => PetMood.happy,
            _ => PetMood.celebrating,
          };
          final bounce = a == null && mood == PetMood.celebrating ? -10 * t : 0.0;
          final sz = widget.size;
          final pi = math.pi;
          final s1 = math.sin(pi * at);
          var dx = 0.0, dy = bounce, rot = 0.0, sx = 1.0, sy = 1.0;
          switch (a) {
            case PetAction.entrenar:
              final q = math.sin(3 * pi * at).abs();
              sy = 1 - 0.16 * q;
              sx = 1 + 0.08 * q;
            case PetAction.bailar:
              rot = math.sin(4 * pi * at) * 0.22;
              dx = math.sin(4 * pi * at) * sz * 0.05;
              dy = -math.sin(8 * pi * at).abs() * sz * 0.04;
            case PetAction.estirar:
              sy = 1 + 0.2 * s1;
              sx = 1 - 0.08 * s1;
            case PetAction.voltereta:
              dy = -s1 * sz * 0.3;
              rot = 2 * pi * Curves.easeInOut.transform(at);
            case PetAction.mimos:
              final q = math.sin(4 * pi * at);
              sx = 1 + 0.04 * q;
              sy = 1 - 0.04 * q;
            case PetAction.agua || PetAction.siesta || null:
              break;
          }
          return Transform.translate(
            offset: Offset(dx, dy),
            child: Transform.rotate(
              angle: rot,
              alignment: a == PetAction.voltereta ? Alignment.center : Alignment.bottomCenter,
              child: Transform(
                alignment: Alignment.bottomCenter,
                transform: Matrix4.diagonal3Values(sx, sy, 1),
                child: CustomPaint(
                  size: Size.square(sz),
                  painter: _PetPainter(mood: mood, breath: t, look: widget.look, action: a, actionT: at),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  static String _moodLabel(PetMood m) => switch (m) {
        PetMood.happy => 'feliz',
        PetMood.resting => 'descansando',
        PetMood.motivating => 'motivándote',
        PetMood.celebrating => 'celebrando',
      };
}

const _gold = Color(0xFFF2C14E);
const _goldDark = Color(0xFFD69E2E);

class _PetPainter extends CustomPainter {
  _PetPainter({required this.mood, required this.breath, required this.look, this.action, this.actionT = 0});

  final PetMood mood;
  final double breath;
  final PetLook look;
  final PetAction? action;
  final double actionT;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w / 2, h * 0.58);
    final scaleY = 1 + 0.035 * breath;
    final bodyW = w * 0.78;
    final bodyH = h * 0.66 * scaleY;
    final top = center.dy - bodyH / 2;
    final (cTop, cBottom) = look.bodyColors;
    final dark = cBottom.computeLuminance() < 0.25;
    final ink = dark ? Colors.white : FmColors.deep;

    // Sombra
    canvas.drawOval(
      Rect.fromCenter(center: Offset(w / 2, h * 0.94), width: bodyW * 0.7, height: h * 0.06),
      Paint()..color = FmColors.deep.withValues(alpha: 0.08),
    );

    if (look.body == 'capa') {
      final cape = Path()
        ..moveTo(center.dx - bodyW * 0.3, center.dy + bodyH * 0.02)
        ..quadraticBezierTo(center.dx - bodyW * 0.62, center.dy + bodyH * 0.42, center.dx - bodyW * 0.56, center.dy + bodyH * 0.5)
        ..lineTo(center.dx + bodyW * 0.56, center.dy + bodyH * 0.5)
        ..quadraticBezierTo(center.dx + bodyW * 0.62, center.dy + bodyH * 0.42, center.dx + bodyW * 0.3, center.dy + bodyH * 0.02)
        ..close();
      canvas.drawPath(cape, Paint()..color = const Color(0xFFE5484D));
    }

    // Orejitas
    final ear = Paint()..color = cBottom;
    for (final dx in [-1, 1]) {
      final p = Path()
        ..moveTo(center.dx + dx * bodyW * 0.18, center.dy - bodyH * 0.42)
        ..quadraticBezierTo(center.dx + dx * bodyW * 0.36, center.dy - bodyH * 0.78,
            center.dx + dx * bodyW * 0.4, center.dy - bodyH * 0.3)
        ..close();
      canvas.drawPath(p, ear);
    }

    // Cuerpo
    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: bodyW, height: bodyH),
      Radius.circular(bodyW * 0.48),
    );
    canvas.drawRRect(
      body,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [cTop, cBottom],
        ).createShader(body.outerRect),
    );
    if (look.colorId == 'galaxia') {
      final star = Paint()..color = Colors.white.withValues(alpha: 0.7);
      for (final (x, y, r) in [(0.3, 0.55, 0.012), (0.68, 0.48, 0.009), (0.6, 0.8, 0.011), (0.36, 0.78, 0.008)]) {
        canvas.drawCircle(Offset(w * x, h * y), w * r, star);
      }
    }

    // Barriguita
    canvas.drawOval(
      Rect.fromCenter(center: center.translate(0, bodyH * 0.18), width: bodyW * 0.5, height: bodyH * 0.42),
      Paint()..color = Colors.white.withValues(alpha: dark ? 0.18 : 0.55),
    );

    _drawBody(canvas, w, center, bodyW, bodyH, body);

    // Mejillas
    final cheek = Paint()..color = const Color(0xFFF4B6D2).withValues(alpha: 0.8);
    for (final dx in [-1, 1]) {
      final at = center.translate(dx * bodyW * 0.27, -bodyH * 0.02);
      if (look.face == 'corazones') {
        canvas.drawPath(_heart(at, w * 0.06), Paint()..color = const Color(0xFFF26D9E));
      } else {
        canvas.drawCircle(at, w * 0.045, cheek);
      }
    }

    // Ojos
    final eye = Paint()
      ..color = ink
      ..strokeWidth = w * 0.03
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final eyeY = center.dy - bodyH * 0.12;
    for (final dx in [-1, 1]) {
      final ex = center.dx + dx * bodyW * 0.17;
      switch (mood) {
        case PetMood.resting:
          canvas.drawArc(Rect.fromCenter(center: Offset(ex, eyeY), width: w * 0.09, height: w * 0.06), 0, math.pi,
              false, eye);
        case PetMood.happy || PetMood.celebrating:
          canvas.drawArc(Rect.fromCenter(center: Offset(ex, eyeY + w * 0.01), width: w * 0.09, height: w * 0.07),
              math.pi, math.pi, false, eye);
        case PetMood.motivating:
          canvas.drawCircle(Offset(ex, eyeY), w * 0.035, Paint()..color = ink);
          canvas.drawCircle(Offset(ex + w * 0.012, eyeY - w * 0.012), w * 0.011,
              Paint()..color = dark ? FmColors.deep : Colors.white);
      }
    }

    // Boca
    final mouth = Paint()
      ..color = ink
      ..strokeWidth = w * 0.025
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final mouthC = Offset(center.dx, center.dy + bodyH * 0.02);
    if (mood == PetMood.resting) {
      canvas.drawCircle(mouthC, w * 0.018, Paint()..color = ink);
    } else {
      final open = mood == PetMood.celebrating ? 0.09 : 0.06;
      canvas.drawArc(Rect.fromCenter(center: mouthC, width: w * 0.12, height: w * open), 0, math.pi, false, mouth);
    }

    // ---- Accesorios ----
    _drawFace(canvas, w, center, bodyW, eyeY);
    _drawNeck(canvas, w, center, bodyW, bodyH);
    final head = look.head ?? (mood == PetMood.motivating ? 'cinta' : null);
    _drawHead(canvas, w, center, bodyW, bodyH, top, head);
    if (action != PetAction.agua) _drawHand(canvas, w, center, bodyW, bodyH, look.hand, cBottom);
    _drawAction(canvas, w, h, center, bodyW, bodyH, top);

    // Detalles por estado
    if (mood == PetMood.resting) {
      final tp = TextPainter(
        textDirection: TextDirection.ltr,
        text: TextSpan(
          text: 'z z',
          style: TextStyle(
            fontSize: w * 0.13,
            color: FmColors.primary.withValues(alpha: 0.4 + 0.5 * breath),
            fontWeight: FontWeight.w800,
          ),
        ),
      )..layout();
      tp.paint(canvas, Offset(w * 0.72, h * 0.05 - 6 * breath));
    } else if (mood == PetMood.celebrating) {
      final spark = Paint()..color = FmColors.mint;
      for (var i = 0; i < 6; i++) {
        final a = i * math.pi / 3 + breath;
        canvas.drawCircle(Offset(w / 2 + math.cos(a) * w * 0.48, h * 0.45 + math.sin(a) * h * 0.42), w * 0.022, spark);
      }
    }
  }

  void _drawHead(Canvas c, double w, Offset center, double bodyW, double bodyH, double top, String? id) {
    final fill = Paint();
    switch (id) {
      case 'cinta':
        c.drawLine(
          Offset(center.dx - bodyW * 0.36, center.dy - bodyH * 0.3),
          Offset(center.dx + bodyW * 0.36, center.dy - bodyH * 0.3),
          Paint()
            ..color = FmColors.primary
            ..strokeWidth = w * 0.05
            ..strokeCap = StrokeCap.round,
        );
      case 'lazo':
        final k = Offset(center.dx + bodyW * 0.22, top + bodyH * 0.08);
        fill.color = const Color(0xFFF26D9E);
        for (final dx in [-1, 1]) {
          c.drawPath(
            Path()
              ..moveTo(k.dx, k.dy)
              ..lineTo(k.dx + dx * w * 0.12, k.dy - w * 0.07)
              ..lineTo(k.dx + dx * w * 0.12, k.dy + w * 0.07)
              ..close(),
            fill,
          );
        }
        c.drawCircle(k, w * 0.03, Paint()..color = const Color(0xFFD94F84));
      case 'flor':
        final k = Offset(center.dx - bodyW * 0.24, top + bodyH * 0.1);
        fill.color = Colors.white;
        for (var i = 0; i < 5; i++) {
          final a = i * 2 * math.pi / 5;
          c.drawCircle(k + Offset(math.cos(a), math.sin(a)) * w * 0.045, w * 0.04, fill);
        }
        c.drawCircle(k, w * 0.035, Paint()..color = _gold);
      case 'gorra':
        final r = Rect.fromCenter(center: Offset(center.dx, top + bodyH * 0.1), width: bodyW * 0.78, height: bodyH * 0.42);
        fill.color = FmColors.primary;
        c.drawArc(r, math.pi, math.pi, true, fill);
        c.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(center.dx - bodyW * 0.05, top + bodyH * 0.07, bodyW * 0.5, w * 0.05),
            Radius.circular(w * 0.03),
          ),
          Paint()..color = FmColors.deep,
        );
        c.drawCircle(Offset(center.dx, r.top + w * 0.01), w * 0.025, Paint()..color = const Color(0xFFDCCBFA));
      case 'gorro_lana':
        final r = Rect.fromCenter(center: Offset(center.dx, top + bodyH * 0.12), width: bodyW * 0.8, height: bodyH * 0.5);
        fill.color = FmColors.mint;
        c.drawArc(r, math.pi, math.pi, true, fill);
        c.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(center.dx, top + bodyH * 0.12), width: bodyW * 0.84, height: w * 0.07),
            Radius.circular(w * 0.035),
          ),
          Paint()..color = const Color(0xFF5DB5A6),
        );
        c.drawCircle(Offset(center.dx, r.top - w * 0.02), w * 0.05, Paint()..color = Colors.white);
      case 'auriculares':
        final band = Paint()
          ..color = FmColors.deep
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.035;
        c.drawArc(
          Rect.fromCenter(center: Offset(center.dx, top + bodyH * 0.3), width: bodyW * 1.02, height: bodyH * 0.75),
          math.pi * 1.05,
          math.pi * 0.9,
          false,
          band,
        );
        for (final dx in [-1, 1]) {
          c.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(
                  center: Offset(center.dx + dx * bodyW * 0.5, center.dy - bodyH * 0.08), width: w * 0.1, height: w * 0.17),
              Radius.circular(w * 0.04),
            ),
            Paint()..color = FmColors.primary,
          );
        }
      case 'corona':
        final y = top + bodyH * 0.04;
        final x0 = center.dx - bodyW * 0.22;
        final cw = bodyW * 0.44;
        final p = Path()
          ..moveTo(x0, y)
          ..lineTo(x0, y - w * 0.11)
          ..lineTo(x0 + cw * 0.25, y - w * 0.05)
          ..lineTo(x0 + cw * 0.5, y - w * 0.14)
          ..lineTo(x0 + cw * 0.75, y - w * 0.05)
          ..lineTo(x0 + cw, y - w * 0.11)
          ..lineTo(x0 + cw, y)
          ..close();
        c.drawPath(p, Paint()..color = _gold);
        c.drawPath(
            p,
            Paint()
              ..color = _goldDark
              ..style = PaintingStyle.stroke
              ..strokeWidth = w * 0.008);
        c.drawCircle(Offset(center.dx, y - w * 0.04), w * 0.018, Paint()..color = const Color(0xFFF26D9E));
      case 'tiara_estrellas':
        final y = top + bodyH * 0.06;
        c.drawArc(
          Rect.fromCenter(center: Offset(center.dx, y + w * 0.04), width: bodyW * 0.5, height: w * 0.12),
          math.pi,
          math.pi,
          false,
          Paint()
            ..color = const Color(0xFFD9D4E4)
            ..style = PaintingStyle.stroke
            ..strokeWidth = w * 0.022,
        );
        for (final (dx, r) in [(-0.16, 0.035), (0.0, 0.05), (0.16, 0.035)]) {
          final k = Offset(center.dx + dx * bodyW, y - w * 0.02 - (dx == 0 ? w * 0.02 : 0));
          c.drawPath(_star(k, w * r), Paint()..color = _gold);
          c.drawPath(_star(k, w * r * 0.45), Paint()..color = Colors.white.withValues(alpha: 0.8));
        }
      case 'orejas_gato':
        c.drawArc(
          Rect.fromCenter(center: Offset(center.dx, top + bodyH * 0.2), width: bodyW * 0.8, height: bodyH * 0.4),
          math.pi * 1.1,
          math.pi * 0.8,
          false,
          Paint()
            ..color = FmColors.deep
            ..style = PaintingStyle.stroke
            ..strokeWidth = w * 0.025,
        );
        for (final dx in [-1, 1]) {
          final b = Offset(center.dx + dx * bodyW * 0.22, top + bodyH * 0.03);
          final ear = Path()
            ..moveTo(b.dx - w * 0.07, b.dy + w * 0.02)
            ..lineTo(b.dx + dx * w * 0.02, b.dy - w * 0.13)
            ..lineTo(b.dx + w * 0.07, b.dy + w * 0.02)
            ..close();
          c.drawPath(ear, Paint()..color = FmColors.deep);
          c.drawPath(
            Path()
              ..moveTo(b.dx - w * 0.035, b.dy + w * 0.005)
              ..lineTo(b.dx + dx * w * 0.012, b.dy - w * 0.08)
              ..lineTo(b.dx + w * 0.035, b.dy + w * 0.005)
              ..close(),
            Paint()..color = const Color(0xFFF4B6D2),
          );
        }
      case 'fiesta':
        final base = top + bodyH * 0.05;
        final cone = Path()
          ..moveTo(center.dx - w * 0.1, base)
          ..lineTo(center.dx + w * 0.04, base - w * 0.22)
          ..lineTo(center.dx + w * 0.1, base)
          ..close();
        c.drawPath(cone, Paint()..color = const Color(0xFF7FD3C1));
        c.save();
        c.clipPath(cone);
        for (var i = 0; i < 4; i++) {
          c.drawLine(
            Offset(center.dx - w * 0.15, base - w * (0.02 + i * 0.06)),
            Offset(center.dx + w * 0.15, base - w * (0.06 + i * 0.06)),
            Paint()
              ..color = const Color(0xFFF26D9E)
              ..strokeWidth = w * 0.022,
          );
        }
        c.restore();
        c.drawCircle(Offset(center.dx + w * 0.04, base - w * 0.22), w * 0.03, Paint()..color = _gold);
      case 'sombrero':
        final y = top + bodyH * 0.07;
        c.drawArc(
          Rect.fromCenter(center: Offset(center.dx, y), width: bodyW * 0.6, height: w * 0.28),
          math.pi,
          math.pi,
          true,
          Paint()..color = const Color(0xFFF2D79B),
        );
        c.drawOval(
          Rect.fromCenter(center: Offset(center.dx, y), width: bodyW * 1.15, height: w * 0.09),
          Paint()..color = const Color(0xFFE8C67A),
        );
        c.drawRect(
          Rect.fromLTWH(center.dx - bodyW * 0.3, y - w * 0.05, bodyW * 0.6, w * 0.035),
          Paint()..color = FmColors.primary,
        );
      case 'corona_flores':
        const colors = [Color(0xFFF26D9E), Colors.white, Color(0xFFF2C14E), Color(0xFFB79CE6), Color(0xFFF26D9E)];
        for (var i = 0; i < 5; i++) {
          final a = math.pi * (1.15 + i * 0.175);
          final k = Offset(center.dx + math.cos(a) * bodyW * 0.36, top + bodyH * 0.24 + math.sin(a) * bodyH * 0.24);
          c.drawCircle(k + Offset(w * 0.03, w * 0.02), w * 0.022, Paint()..color = const Color(0xFF6CC28A));
          for (var j = 0; j < 5; j++) {
            final b = j * 2 * math.pi / 5;
            c.drawCircle(k + Offset(math.cos(b), math.sin(b)) * w * 0.025, w * 0.022, Paint()..color = colors[i]);
          }
          c.drawCircle(k, w * 0.016, Paint()..color = _goldDark);
        }
    }
  }

  /// Ropa: recortada a la forma del cuerpo.
  void _drawBody(Canvas c, double w, Offset center, double bodyW, double bodyH, RRect body) {
    final id = look.body;
    if (id == null || id == 'capa') {
      if (id == 'capa') {
        for (final dx in [-1, 1]) {
          c.drawCircle(Offset(center.dx + dx * bodyW * 0.28, center.dy + bodyH * 0.06), w * 0.025, Paint()..color = _gold);
        }
      }
      return;
    }
    final y0 = center.dy + bodyH * 0.09;
    final bottom = body.outerRect.bottom;
    c.save();
    c.clipRRect(body);
    switch (id) {
      case 'top':
        final r = Rect.fromLTRB(body.left, y0, body.right, center.dy + bodyH * 0.27);
        c.drawRect(r, Paint()..color = const Color(0xFFF26D9E));
        c.drawRect(Rect.fromLTRB(r.left, r.bottom - w * 0.025, r.right, r.bottom), Paint()..color = Colors.white.withValues(alpha: 0.8));
      case 'camiseta':
        c.drawRect(Rect.fromLTRB(body.left, y0, body.right, bottom), Paint()..color = FmColors.primary);
        c.drawRect(
          Rect.fromLTRB(body.left, y0 + bodyH * 0.06, body.right, y0 + bodyH * 0.06 + w * 0.025),
          Paint()..color = Colors.white.withValues(alpha: 0.85),
        );
        final tp = TextPainter(
          textDirection: TextDirection.ltr,
          text: TextSpan(text: '1', style: TextStyle(color: Colors.white, fontSize: w * 0.13, fontWeight: FontWeight.w900)),
        )..layout();
        tp.paint(c, Offset(center.dx - tp.width / 2, y0 + bodyH * 0.12));
      case 'sudadera':
        c.drawRect(Rect.fromLTRB(body.left, y0, body.right, bottom), Paint()..color = const Color(0xFFB9B4C4));
        c.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(center.dx, y0 + bodyH * 0.25), width: bodyW * 0.42, height: bodyH * 0.14),
            Radius.circular(w * 0.03),
          ),
          Paint()..color = const Color(0xFFA29CB0),
        );
        final cord = Paint()
          ..color = Colors.white
          ..strokeWidth = w * 0.012
          ..strokeCap = StrokeCap.round;
        for (final dx in [-1, 1]) {
          c.drawLine(Offset(center.dx + dx * w * 0.04, y0), Offset(center.dx + dx * w * 0.045, y0 + w * 0.09), cord);
        }
      case 'chaqueta_dorada':
        c.drawRect(Rect.fromLTRB(body.left, y0, body.right, bottom), Paint()..color = const Color(0xFFE8B84A));
        final lapel = Paint()..color = const Color(0xFFC9952B);
        for (final dx in [-1, 1]) {
          c.drawPath(
            Path()
              ..moveTo(center.dx, y0 + bodyH * 0.12)
              ..lineTo(center.dx + dx * bodyW * 0.18, y0)
              ..lineTo(center.dx + dx * bodyW * 0.08, y0)
              ..close(),
            lapel,
          );
        }
        c.drawLine(Offset(center.dx, y0 + bodyH * 0.12), Offset(center.dx, bottom), Paint()
          ..color = const Color(0xFFC9952B)
          ..strokeWidth = w * 0.01);
        for (var k = 0; k < 3; k++) {
          c.drawCircle(Offset(center.dx + w * 0.03, y0 + bodyH * (0.17 + k * 0.08)), w * 0.012, Paint()..color = Colors.white);
        }
      case 'pijama':
        c.drawRect(Rect.fromLTRB(body.left, y0, body.right, bottom), Paint()..color = const Color(0xFF9CC1F2));
        final star = Paint()..color = Colors.white.withValues(alpha: 0.9);
        for (final (x, y) in [(-0.25, 0.08), (0.05, 0.14), (0.28, 0.06), (-0.12, 0.26), (0.2, 0.27), (-0.3, 0.35), (0.02, 0.38)]) {
          c.drawPath(_star(Offset(center.dx + x * bodyW, y0 + y * bodyH), w * 0.025), star);
        }
      case 'tutu':
        c.drawRect(
          Rect.fromLTRB(body.left, center.dy + bodyH * 0.16, body.right, center.dy + bodyH * 0.21),
          Paint()..color = const Color(0xFFD94F84),
        );
    }
    c.restore();
    if (id == 'tutu') {
      final y = center.dy + bodyH * 0.25;
      final frill = Paint()..color = const Color(0xFFF7A8C8).withValues(alpha: 0.92);
      for (var i = 0; i <= 8; i++) {
        final x = center.dx + (i / 8 - 0.5) * bodyW * 1.08;
        c.drawCircle(Offset(x, y + (i.isEven ? 0 : w * 0.02)), w * 0.045, frill);
      }
    }
  }

  /// Objeto que sostiene a un lado, con una manita.
  void _drawHand(Canvas c, double w, Offset center, double bodyW, double bodyH, String? id, Color skin) {
    if (id == null) return;
    final a = Offset(center.dx + bodyW * 0.47, center.dy + bodyH * 0.14);
    switch (id) {
      case 'mancuerna':
        c.drawLine(a.translate(0, -w * 0.1), a.translate(0, w * 0.1), Paint()
          ..color = const Color(0xFF9A93A6)
          ..strokeWidth = w * 0.025);
        for (final dy in [-1, 1]) {
          c.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(center: a.translate(0, dy * w * 0.1), width: w * 0.1, height: w * 0.05),
              Radius.circular(w * 0.015),
            ),
            Paint()..color = const Color(0xFF5A5363),
          );
        }
      case 'botella':
        c.drawRRect(
          RRect.fromRectAndRadius(Rect.fromCenter(center: a.translate(0, -w * 0.04), width: w * 0.08, height: w * 0.18), Radius.circular(w * 0.025)),
          Paint()..color = const Color(0xFF4FB3D9),
        );
        c.drawRect(Rect.fromCenter(center: a.translate(0, -w * 0.14), width: w * 0.05, height: w * 0.03), Paint()..color = FmColors.deep);
      case 'pesa_rusa':
        c.drawArc(
          Rect.fromCenter(center: a.translate(0, w * 0.01), width: w * 0.09, height: w * 0.09),
          math.pi,
          math.pi,
          false,
          Paint()
            ..color = const Color(0xFF3B3445)
            ..style = PaintingStyle.stroke
            ..strokeWidth = w * 0.022,
        );
        c.drawCircle(a.translate(0, w * 0.08), w * 0.07, Paint()..color = const Color(0xFF3B3445));
      case 'esterilla':
        c.drawRRect(
          RRect.fromRectAndRadius(Rect.fromCenter(center: a.translate(w * 0.01, -w * 0.02), width: w * 0.09, height: w * 0.26), Radius.circular(w * 0.04)),
          Paint()..color = const Color(0xFFF2A5C6),
        );
        c.drawCircle(a.translate(w * 0.01, -w * 0.13), w * 0.035, Paint()..color = const Color(0xFFD97FA6));
      case 'globo':
        final top = a.translate(w * 0.06, -w * 0.32);
        c.drawLine(a, top.translate(0, w * 0.06), Paint()
          ..color = FmColors.muted
          ..strokeWidth = w * 0.008);
        c.drawPath(_heart(top, w * 0.13), Paint()..color = const Color(0xFFF26D9E));
      case 'pompones':
        final k = a.translate(w * 0.02, -w * 0.04);
        const cols = [Color(0xFFF26D9E), Color(0xFFB79CE6), Colors.white];
        for (var i = 0; i < 14; i++) {
          final ang = i * 2 * math.pi / 14;
          c.drawLine(k, k + Offset(math.cos(ang), math.sin(ang)) * w * 0.09, Paint()
            ..color = cols[i % 3]
            ..strokeWidth = w * 0.025
            ..strokeCap = StrokeCap.round);
        }
      case 'trofeo':
        final k = a.translate(0, -w * 0.05);
        c.drawPath(
          Path()
            ..moveTo(k.dx - w * 0.07, k.dy - w * 0.07)
            ..lineTo(k.dx + w * 0.07, k.dy - w * 0.07)
            ..quadraticBezierTo(k.dx + w * 0.06, k.dy + w * 0.04, k.dx, k.dy + w * 0.05)
            ..quadraticBezierTo(k.dx - w * 0.06, k.dy + w * 0.04, k.dx - w * 0.07, k.dy - w * 0.07)
            ..close(),
          Paint()..color = _gold,
        );
        c.drawRect(Rect.fromCenter(center: k.translate(0, w * 0.08), width: w * 0.025, height: w * 0.05), Paint()..color = _goldDark);
        c.drawRect(Rect.fromCenter(center: k.translate(0, w * 0.115), width: w * 0.09, height: w * 0.025), Paint()..color = _goldDark);
    }
    // Manita
    c.drawOval(Rect.fromCenter(center: a.translate(-w * 0.025, 0), width: w * 0.11, height: w * 0.075), Paint()..color = skin);
  }

  /// Detalles de cada acción (corazones, notas, agua…).
  void _drawAction(Canvas c, double w, double h, Offset center, double bodyW, double bodyH, double top) {
    final a = action;
    if (a == null) return;
    final t = actionT;
    switch (a) {
      case PetAction.mimos:
        for (var i = 0; i < 4; i++) {
          final f = ((t * 1.6) - i * 0.18).clamp(0.0, 1.0);
          if (f <= 0) continue;
          final x = center.dx + (i.isEven ? -1 : 1) * bodyW * (0.25 + 0.1 * i / 3);
          final y = top + bodyH * 0.2 - f * h * 0.3;
          c.drawPath(_heart(Offset(x, y), w * (0.07 + 0.02 * (i % 2))),
              Paint()..color = const Color(0xFFF26D9E).withValues(alpha: 1 - f * 0.8));
        }
      case PetAction.bailar:
        for (var i = 0; i < 3; i++) {
          final f = (t * 2 + i / 3) % 1.0;
          final tp = TextPainter(
            textDirection: TextDirection.ltr,
            text: TextSpan(
              text: i.isEven ? '♪' : '♫',
              style: TextStyle(fontSize: w * 0.14, color: FmColors.primary.withValues(alpha: 1 - f)),
            ),
          )..layout();
          tp.paint(c, Offset(center.dx + (i - 1) * bodyW * 0.5, top - f * h * 0.15));
        }
      case PetAction.agua:
        final mouth = Offset(center.dx, center.dy + bodyH * 0.02);
        final k = mouth.translate(w * 0.12, -w * 0.08);
        c.save();
        c.translate(k.dx, k.dy);
        c.rotate(-0.9 - 0.3 * math.sin(math.pi * t));
        c.drawRRect(
          RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: w * 0.09, height: w * 0.2), Radius.circular(w * 0.03)),
          Paint()..color = const Color(0xFF4FB3D9),
        );
        c.drawRect(Rect.fromCenter(center: Offset(0, -w * 0.11), width: w * 0.05, height: w * 0.03), Paint()..color = FmColors.deep);
        c.restore();
        for (var i = 0; i < 3; i++) {
          final f = (t * 3 + i / 3) % 1.0;
          c.drawCircle(mouth.translate(w * (0.02 + 0.03 * i), w * 0.03 + f * h * 0.1), w * 0.015,
              Paint()..color = const Color(0xFF4FB3D9).withValues(alpha: 1 - f));
        }
      case PetAction.entrenar:
        final q = math.sin(3 * math.pi * t).abs();
        c.drawCircle(Offset(center.dx + bodyW * 0.42, top + bodyH * 0.2 + q * w * 0.04), w * 0.022,
            Paint()..color = const Color(0xFF4FB3D9).withValues(alpha: 0.8));
      case PetAction.estirar:
        final p = Paint()
          ..color = FmColors.mint.withValues(alpha: math.sin(math.pi * t))
          ..strokeWidth = w * 0.015
          ..strokeCap = StrokeCap.round;
        for (final dx in [-1, 1]) {
          c.drawLine(Offset(center.dx + dx * bodyW * 0.55, center.dy - w * 0.05), Offset(center.dx + dx * bodyW * 0.68, center.dy - w * 0.12), p);
          c.drawLine(Offset(center.dx + dx * bodyW * 0.55, center.dy + w * 0.03), Offset(center.dx + dx * bodyW * 0.7, center.dy + w * 0.03), p);
        }
      case PetAction.voltereta:
        final spark = Paint()..color = _gold.withValues(alpha: math.sin(math.pi * t));
        for (var i = 0; i < 5; i++) {
          final ang = i * 2 * math.pi / 5 + t * 4;
          c.drawPath(_star(Offset(w / 2 + math.cos(ang) * w * 0.46, h * 0.5 + math.sin(ang) * h * 0.42), w * 0.03), spark);
        }
      case PetAction.siesta:
        break;
    }
  }

  static Path _heart(Offset c, double s) => Path()
    ..moveTo(c.dx, c.dy + s * 0.35)
    ..cubicTo(c.dx - s * 0.9, c.dy - s * 0.2, c.dx - s * 0.35, c.dy - s * 0.75, c.dx, c.dy - s * 0.3)
    ..cubicTo(c.dx + s * 0.35, c.dy - s * 0.75, c.dx + s * 0.9, c.dy - s * 0.2, c.dx, c.dy + s * 0.35)
    ..close();

  static Path _star(Offset c, double r) {
    final p = Path();
    for (var i = 0; i < 10; i++) {
      final rr = i.isEven ? r : r * 0.45;
      final a = -math.pi / 2 + i * math.pi / 5;
      final o = c + Offset(math.cos(a), math.sin(a)) * rr;
      i == 0 ? p.moveTo(o.dx, o.dy) : p.lineTo(o.dx, o.dy);
    }
    return p..close();
  }

  void _drawFace(Canvas c, double w, Offset center, double bodyW, double eyeY) {
    switch (look.face) {
      case 'gafas_corazon':
        for (final dx in [-1, 1]) {
          final k = Offset(center.dx + dx * bodyW * 0.17, eyeY + w * 0.01);
          c.drawPath(_heart(k, w * 0.15), Paint()..color = const Color(0xFFF26D9E).withValues(alpha: 0.85));
        }
        c.drawLine(Offset(center.dx - bodyW * 0.08, eyeY - w * 0.01), Offset(center.dx + bodyW * 0.08, eyeY - w * 0.01), Paint()
          ..color = const Color(0xFFD94F84)
          ..strokeWidth = w * 0.018);
      case 'gafas_natacion':
        c.drawLine(Offset(center.dx - bodyW * 0.5, eyeY), Offset(center.dx + bodyW * 0.5, eyeY), Paint()
          ..color = FmColors.deep
          ..strokeWidth = w * 0.025);
        for (final dx in [-1, 1]) {
          final r = Rect.fromCenter(center: Offset(center.dx + dx * bodyW * 0.17, eyeY), width: w * 0.15, height: w * 0.11);
          c.drawOval(r, Paint()..color = const Color(0xFF7FD3C1).withValues(alpha: 0.75));
          c.drawOval(r, Paint()
            ..color = const Color(0xFF3FA08A)
            ..style = PaintingStyle.stroke
            ..strokeWidth = w * 0.015);
        }
      case 'gafas':
        final p = Paint()
          ..color = FmColors.deep
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.018;
        for (final dx in [-1, 1]) {
          c.drawCircle(Offset(center.dx + dx * bodyW * 0.17, eyeY), w * 0.075, p);
        }
        c.drawLine(Offset(center.dx - bodyW * 0.07, eyeY), Offset(center.dx + bodyW * 0.07, eyeY), p);
      case 'gafas_sol':
        final p = Paint()..color = FmColors.deep;
        for (final dx in [-1, 1]) {
          c.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(center: Offset(center.dx + dx * bodyW * 0.17, eyeY), width: w * 0.17, height: w * 0.11),
              Radius.circular(w * 0.04),
            ),
            p,
          );
        }
        c.drawLine(
          Offset(center.dx - bodyW * 0.07, eyeY - w * 0.01),
          Offset(center.dx + bodyW * 0.07, eyeY - w * 0.01),
          Paint()
            ..color = FmColors.deep
            ..strokeWidth = w * 0.02,
        );
        c.drawLine(
          Offset(center.dx - bodyW * 0.22, eyeY - w * 0.03),
          Offset(center.dx - bodyW * 0.17, eyeY - w * 0.03),
          Paint()
            ..color = Colors.white.withValues(alpha: 0.6)
            ..strokeWidth = w * 0.012,
        );
    }
  }

  void _drawNeck(Canvas c, double w, Offset center, double bodyW, double bodyH) {
    final y = center.dy + bodyH * 0.13;
    switch (look.neck) {
      case 'banda_campeona':
        final sash = Path()
          ..moveTo(center.dx - bodyW * 0.42, y - w * 0.1)
          ..lineTo(center.dx - bodyW * 0.3, y - w * 0.15)
          ..lineTo(center.dx + bodyW * 0.42, y + w * 0.17)
          ..lineTo(center.dx + bodyW * 0.3, y + w * 0.22)
          ..close();
        c.save();
        c.clipRRect(RRect.fromRectAndRadius(
          Rect.fromCenter(center: center, width: bodyW, height: bodyH),
          Radius.circular(bodyW * 0.48),
        ));
        c.drawPath(sash, Paint()..color = const Color(0xFFE5484D));
        c.restore();
        c.drawPath(_star(Offset(center.dx, y + w * 0.035), w * 0.04), Paint()..color = _gold);
      case 'silbato':
        final cord = Paint()
          ..color = FmColors.primary
          ..strokeWidth = w * 0.012;
        c.drawLine(Offset(center.dx - w * 0.1, y - w * 0.04), Offset(center.dx, y + w * 0.05), cord);
        c.drawLine(Offset(center.dx + w * 0.1, y - w * 0.04), Offset(center.dx, y + w * 0.05), cord);
        c.drawRRect(
          RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(center.dx + w * 0.02, y + w * 0.07), width: w * 0.09, height: w * 0.05), Radius.circular(w * 0.02)),
          Paint()..color = _gold,
        );
        c.drawCircle(Offset(center.dx - w * 0.015, y + w * 0.075), w * 0.028, Paint()..color = _gold);
      case 'hawaiano':
        const cols = [Color(0xFFF26D9E), Color(0xFFF2C14E), Colors.white, Color(0xFFB79CE6)];
        for (var i = -4; i <= 4; i++) {
          final k = Offset(center.dx + i * w * 0.05, y - w * 0.02 + (i * i) * w * 0.004);
          for (var j = 0; j < 5; j++) {
            final b = j * 2 * math.pi / 5;
            c.drawCircle(k + Offset(math.cos(b), math.sin(b)) * w * 0.016, w * 0.016, Paint()..color = cols[(i + 4) % 4]);
          }
          c.drawCircle(k, w * 0.01, Paint()..color = _goldDark);
        }
      case 'pajarita':
        final p = Paint()..color = const Color(0xFFE5484D);
        for (final dx in [-1, 1]) {
          c.drawPath(
            Path()
              ..moveTo(center.dx, y)
              ..lineTo(center.dx + dx * w * 0.09, y - w * 0.05)
              ..lineTo(center.dx + dx * w * 0.09, y + w * 0.05)
              ..close(),
            p,
          );
        }
        c.drawCircle(Offset(center.dx, y), w * 0.022, Paint()..color = const Color(0xFFB8333A));
      case 'collar':
        for (var i = -4; i <= 4; i++) {
          final x = center.dx + i * w * 0.045;
          final dy = (i * i) * w * 0.0035;
          c.drawCircle(Offset(x, y - w * 0.02 + dy), w * 0.02, Paint()..color = Colors.white);
          c.drawCircle(
              Offset(x, y - w * 0.02 + dy),
              w * 0.02,
              Paint()
                ..color = const Color(0xFFE6DDF2)
                ..style = PaintingStyle.stroke
                ..strokeWidth = w * 0.004);
        }
      case 'bufanda':
        final p = Paint()..color = const Color(0xFFE5484D);
        c.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(center.dx, y), width: bodyW * 0.72, height: w * 0.08),
            Radius.circular(w * 0.04),
          ),
          p,
        );
        c.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(center.dx + bodyW * 0.12, y, w * 0.08, w * 0.17),
            Radius.circular(w * 0.03),
          ),
          p,
        );
        final stripe = Paint()
          ..color = Colors.white.withValues(alpha: 0.7)
          ..strokeWidth = w * 0.01;
        c.drawLine(Offset(center.dx + bodyW * 0.12, y + w * 0.12), Offset(center.dx + bodyW * 0.12 + w * 0.08, y + w * 0.12),
            stripe);
      case 'medalla':
        final ribbon = Paint()
          ..color = FmColors.primary
          ..strokeWidth = w * 0.03
          ..strokeCap = StrokeCap.round;
        c.drawLine(Offset(center.dx - w * 0.08, y - w * 0.04), Offset(center.dx, y + w * 0.05), ribbon);
        c.drawLine(Offset(center.dx + w * 0.08, y - w * 0.04), Offset(center.dx, y + w * 0.05), ribbon);
        c.drawCircle(Offset(center.dx, y + w * 0.08), w * 0.045, Paint()..color = _gold);
        c.drawCircle(
            Offset(center.dx, y + w * 0.08),
            w * 0.03,
            Paint()
              ..color = _goldDark
              ..style = PaintingStyle.stroke
              ..strokeWidth = w * 0.008);
    }
  }

  @override
  bool shouldRepaint(_PetPainter old) =>
      old.breath != breath || old.mood != mood || old.look != look || old.action != action || old.actionT != actionT;
}
