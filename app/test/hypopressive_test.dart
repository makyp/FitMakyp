import 'dart:io';
import 'dart:ui' as ui;

import 'package:fitmakyp/features/morning/domain/hypopressive.dart';
import 'package:fitmakyp/features/morning/ui/hypo_figure.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cada repetición: 3 respiraciones, vaciar, apnea, soltar y recuperar', () {
    final steps = buildHypoSteps(HypoLevel.suave);
    final first = steps.where((s) => s.postureIndex == 0).toList();
    expect(first.first.phase, BreathPhase.prepare);
    expect(first.where((s) => s.phase == BreathPhase.apnea).length, HypoLevel.suave.reps);
    expect(first.where((s) => s.phase == BreathPhase.inhale).length, 3 * HypoLevel.suave.reps);
    expect(steps.where((s) => s.phase == BreathPhase.apnea).every((s) => s.seconds == 8), isTrue);
    expect(steps.map((s) => s.postureIndex).toSet().length, hypoPostures.length);
  });

  test('duración razonable por nivel', () {
    expect(hypoTotalSeconds(HypoLevel.suave) / 60, inInclusiveRange(6, 10));
    expect(hypoTotalSeconds(HypoLevel.avanzada), greaterThan(hypoTotalSeconds(HypoLevel.media)));
  });

  test('en la apnea el abdomen se mete y en la inhalación sale', () {
    expect(breathShapeAt(BreathPhase.apnea, 5, 8).belly, lessThan(-1));
    expect(breathShapeAt(BreathPhase.inhale, 3, 3).belly, greaterThan(0.5));
    expect(breathShapeAt(BreathPhase.recover, 8, 8).belly, 0);
  });

  test('imagen de muestra de las posturas', () async {
    final out = Platform.environment['FM_HYPO_OUT'];
    if (out == null) return;
    const size = Size(260, 300);
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    for (final (row, apnea) in [false, true].indexed) {
      for (final (i, p) in hypoPostures.indexed) {
        c.save();
        c.translate(i * size.width, row * size.height);
        c.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFFBF8FF));
        HypoFigurePainter(
          pose: p.pose,
          shape: apnea ? breathShapeAt(BreathPhase.apnea, 4, 8) : breathShapeAt(BreathPhase.inhale, 3, 3),
          air: apnea ? 0 : 1,
          anim: 0.3,
          cues: apnea,
        ).paint(c, size);
        c.restore();
      }
    }
    final img = await rec.endRecording().toImage((size.width * 5).round(), (size.height * 2).round());
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    File(out).writeAsBytesSync(png!.buffer.asUint8List());
  });
}
