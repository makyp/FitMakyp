import 'package:flutter/material.dart';

import '../../../shared/widgets/body_figure.dart';
import '../domain/hypopressive.dart';

/// Ilustración de la postura de hipopresivos que "respira":
/// el pecho y el abdomen cambian con [shape] y el aire entra o sale por la nariz.
class HypoFigurePainter extends CustomPainter {
  HypoFigurePainter({
    required this.pose,
    this.shape = BreathShape.rest,
    this.air = 0,
    this.anim = 0,
    this.cues = false,
    this.dark = false,
    this.bun = true,
    this.scene = true,
  });

  final PoseSpec pose;
  final BreathShape shape;

  /// 1 = entra aire (inhala), −1 = sale (exhala), 0 = nada.
  final int air;

  /// 0…1 repetido, para mover el aire y las flechas.
  final double anim;

  /// Flechas de apnea: crecer y ombligo adentro.
  final bool cues;
  final bool dark;

  /// Pelo largo recogido (false = pelo corto, para hombres).
  final bool bun;
  final bool scene;

  static FigurePose figureOf(PoseSpec p) => FigurePose.standing(
        lean: p.lean,
        knees: p.knees,
        shoulder: p.shoulder,
        elbow: p.elbow,
        handsOnThighs: p.handsOnThighs,
      );

  @override
  void paint(Canvas canvas, Size size) => BodyFigurePainter(
        pose: figureOf(pose),
        chest: shape.chest,
        belly: shape.belly,
        ribs: shape.ribs,
        air: air,
        anim: anim,
        cues: cues,
        wall: pose.wall,
        hair: bun ? FigureHair.ponytail : FigureHair.short,
        dark: dark,
        scene: scene,
      ).paint(canvas, size);

  @override
  bool shouldRepaint(HypoFigurePainter o) => true;
}
