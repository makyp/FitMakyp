import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../core/models/exercise.dart';
import '../../core/theme/app_theme.dart';

/// Único lugar que sabe pintar recursos visuales de ejercicios.
/// Para añadir GIF, vídeo, Lottie o 3D solo se toca este widget.
class ExerciseMediaView extends StatelessWidget {
  const ExerciseMediaView({super.key, required this.media, this.height = 200, this.animate = true});

  final ExerciseMedia media;
  final double height;

  /// false = imagen fija (miniaturas, listas largas).
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final Widget child = switch (media.kind) {
      MediaKind.imagePair when animate && !reduceMotion =>
        MovementAnimation(start: media.src!, end: media.endSrc!),
      MediaKind.imagePair => _image(media.src),
      MediaKind.holdImage when animate && !reduceMotion => _HoldAnimation(src: media.src!),
      MediaKind.holdImage || MediaKind.combinedImage || MediaKind.gif => _image(media.src),
      MediaKind.video || MediaKind.none => const _Placeholder(),
    };
    return Semantics(
      label: media.alt,
      image: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          height: height,
          width: double.infinity,
          color: FmColors.line,
          alignment: Alignment.center,
          child: child,
        ),
      ),
    );
  }

  static Widget _image(String? src) {
    if (src == null) return const _Placeholder();
    // Las fotos (jpg) llenan el recuadro; las ilustraciones con transparencia (png) se ven completas.
    final isPhoto = src.endsWith('.jpg');
    return Image.asset(
      src,
      fit: isPhoto ? BoxFit.cover : BoxFit.contain,
      width: isPhoto ? double.infinity : null,
      height: isPhoto ? double.infinity : null,
      filterQuality: FilterQuality.high,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => const _Placeholder(),
    );
  }
}

/// Simula una repetición: posición inicial → movimiento → posición final → vuelta.
/// Durante el cambio aplica un leve desenfoque y desplazamiento que dan sensación de movimiento.
/// Tocar la imagen pausa o reanuda.
class MovementAnimation extends StatefulWidget {
  const MovementAnimation({
    super.key,
    required this.start,
    required this.end,
    this.repDuration = const Duration(milliseconds: 3200),
  });

  final String start;
  final String end;
  final Duration repDuration;

  @override
  State<MovementAnimation> createState() => _MovementAnimationState();
}

class _MovementAnimationState extends State<MovementAnimation> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.repDuration)..repeat();
  bool _paused = false;

  // Fases de la repetición (fracciones del ciclo).
  static const _holdStart = 0.28;
  static const _toEnd = 0.20; // concéntrica
  static const _holdEnd = 0.24;
  // el resto (0.28) es la vuelta, algo más lenta (excéntrica controlada)

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Precarga para que el primer cambio no parpadee.
    precacheImage(AssetImage(widget.start), context);
    precacheImage(AssetImage(widget.end), context);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _paused = !_paused);
    _paused ? _c.stop() : _c.repeat();
  }

  /// 0 = posición inicial, 1 = posición final.
  static double _progress(double t) {
    const a = _holdStart;
    const b = a + _toEnd;
    const c = b + _holdEnd;
    if (t < a) return 0;
    if (t < b) return Curves.easeInOutCubic.transform((t - a) / _toEnd);
    if (t < c) return 1;
    return 1 - Curves.easeInOutSine.transform((t - c) / (1 - c));
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return GestureDetector(
      onTap: _toggle,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final p = _progress(_c.value);
          // Máximo en mitad del movimiento, 0 en las posiciones.
          final motion = math.sin(p * math.pi);
          final blur = 1.6 * motion;
          final atEnd = p > 0.5;

          Widget frame(String src, double opacity, double dx) => Opacity(
                opacity: opacity.clamp(0.0, 1.0),
                child: Transform.translate(
                  offset: Offset(dx, -3 * motion),
                  child: ExerciseMediaView._image(src),
                ),
              );

          return Stack(
            fit: StackFit.expand,
            children: [
              ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: blur, sigmaY: blur * 0.6),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    frame(widget.start, 1 - Curves.easeIn.transform(p), -2 * p),
                    frame(widget.end, Curves.easeOut.transform(p), 2 * (1 - p)),
                  ],
                ),
              ),
              // Etiqueta de fase
              Positioned(
                left: 10,
                top: 10,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: _Pill(
                    key: ValueKey(atEnd),
                    text: atEnd ? 'Posición final' : 'Posición inicial',
                    style: t.labelSmall,
                  ),
                ),
              ),
              // Barra de progreso de la repetición
              Positioned(
                left: 14,
                right: 14,
                bottom: 10,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: p,
                    minHeight: 4,
                    backgroundColor: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              ),
              if (_paused)
                const Center(
                  child: CircleAvatar(
                    radius: 26,
                    backgroundColor: Color(0xCC2B1B43),
                    child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 32),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Ejercicios isométricos: la figura "respira" levemente y un anillo marca que se mantiene.
class _HoldAnimation extends StatefulWidget {
  const _HoldAnimation({required this.src});
  final String src;

  @override
  State<_HoldAnimation> createState() => _HoldAnimationState();
}

class _HoldAnimationState extends State<_HoldAnimation> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final v = Curves.easeInOut.transform(_c.value);
        return Stack(
          fit: StackFit.expand,
          children: [
            Transform.scale(scale: 1 + 0.012 * v, child: child),
            Positioned(
              left: 10,
              top: 10,
              child: _Pill(text: 'Mantén la posición', style: t.labelSmall, glow: v),
            ),
          ],
        );
      },
      child: ExerciseMediaView._image(widget.src),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({super.key, required this.text, this.style, this.glow = 0});
  final String text;
  final TextStyle? style;
  final double glow;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Color.lerp(FmColors.lavender, FmColors.primary, glow)!, width: 1.2),
        ),
        child: Text(text, style: style?.copyWith(color: FmColors.primary, fontWeight: FontWeight.w800)),
      );
}

class _Placeholder extends StatelessWidget {
  const _Placeholder();

  @override
  Widget build(BuildContext context) =>
      const Icon(Icons.fitness_center_rounded, size: 56, color: FmColors.lilac);
}
