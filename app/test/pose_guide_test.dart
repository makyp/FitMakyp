import 'dart:io';
import 'dart:ui' as ui;

import 'package:fitmakyp/core/models/body.dart';
import 'package:fitmakyp/features/evolution/ui/pose_guide.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const size = Size(300, 400);
  const measures = {Measure.cintura: 70.0, Measure.cadera: 98.0, Measure.pecho: 88.0};

  for (final a in PhotoAngle.values) {
    test('la silueta ${a.label} va de la línea de la cabeza a la de los pies', () {
      final b = poseOutline(size, a, measures, 162).getBounds();
      expect(b.top, closeTo(size.height * poseHeadTop, 3));
      expect(b.bottom, closeTo(size.height * poseFeet, 3));
      expect(b.center.dx, closeTo(size.width / 2, size.width * 0.08), reason: 'centrada');
      expect(b.width, lessThan(size.width * 0.9));
    });
  }

  test('las medidas cambian la silueta de frente', () {
    final slim = poseOutline(size, PhotoAngle.frontal, const {Measure.cadera: 88, Measure.cintura: 64}, 162).getBounds();
    final wide = poseOutline(size, PhotoAngle.frontal, const {Measure.cadera: 115, Measure.cintura: 90}, 162).getBounds();
    expect(wide.width, greaterThanOrEqualTo(slim.width));
  });

  test('imagen de muestra de las guías', () async {
    final out = Platform.environment['FM_GUIDE_OUT'];
    if (out == null) return;
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    for (final (i, a) in PhotoAngle.values.indexed) {
      c.save();
      c.translate(i * size.width, 0);
      c.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF5A5363));
      PoseGuidePainter(angle: a, measures: measures, heightCm: 162).paint(c, size);
      c.restore();
    }
    final img = await rec.endRecording().toImage((size.width * 3).round(), size.height.round());
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    File(out).writeAsBytesSync(png!.buffer.asUint8List());
  });
}
