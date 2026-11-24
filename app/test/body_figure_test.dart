import 'dart:io';
import 'dart:ui' as ui;

import 'package:fitmakyp/shared/widgets/body_figure.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('las posturas se interpolan', () {
    final m = BoxingPoses.guard.lerp(BoxingPoses.jab, 0.5);
    expect(m.frontShoulder, closeTo((BoxingPoses.guard.frontShoulder + BoxingPoses.jab.frontShoulder) / 2, 0.01));
  });

  test('imagen de muestra de la figura', () async {
    final out = Platform.environment['FM_FIG_OUT'];
    if (out == null) return;
    const size = Size(240, 300);
    final poses = <(FigurePose, bool, bool, double, bool)>[
      (const FigurePose.standing(lean: 4, knees: 10, shoulder: 18, elbow: 8), false, false, 0, false),
      (const FigurePose.standing(lean: 6, knees: 12, shoulder: 78, elbow: 55), false, false, 0, false),
      (const FigurePose.standing(lean: 32, knees: 30, handsOnThighs: true), false, false, -1.5, true),
      (const FigurePose.standing(lean: 3, knees: 10, shoulder: 172, elbow: 4), false, false, -1.5, true),
      (const FigurePose.standing(lean: 0, knees: 18, shoulder: 78, elbow: 55), true, false, 0, false),
      (BoxingPoses.guard, false, true, 0, false),
      (BoxingPoses.jab, false, true, 0, false),
      (BoxingPoses.cross, false, true, 0, false),
      (BoxingPoses.hook, false, true, 0, false),
      (BoxingPoses.uppercut, false, true, 0, false),
    ];
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    for (final (i, (p, wall, gloves, belly, cues)) in poses.indexed) {
      c.save();
      c.translate((i % 5) * size.width, (i ~/ 5) * size.height);
      c.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFFBF8FF));
      BodyFigurePainter(pose: p, wall: wall, gloves: gloves, belly: belly, ribs: cues ? 1 : 0, chest: cues ? 0.7 : 0, cues: cues, air: i == 0 ? 1 : 0, anim: 0.3).paint(c, size);
      c.restore();
    }
    final img = await rec.endRecording().toImage((size.width * 5).round(), (size.height * 2).round());
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    File(out).writeAsBytesSync(png!.buffer.asUint8List());
  });
}
