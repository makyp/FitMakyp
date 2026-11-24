import 'package:fitmakyp/core/models/exercise.dart';
import 'package:fitmakyp/features/workout/domain/warmup.dart';
import 'package:fitmakyp/features/workout/ui/phase_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('las miniaturas del calentamiento caben en un teléfono angosto', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final moves = cooldownFor(MuscleGroup.values);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ListView(
          children: [
            PhaseCard(
              phase: RoutinePhase.cooldown,
              moves: moves,
              status: null,
              onDo: () {},
              onAlready: () {},
              onSkip: () {},
            ),
            MoveMedia(move: moves.last, height: 250),
          ],
        ),
      ),
    ));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
    expect(find.byType(MoveThumb), findsWidgets);
  });
}
