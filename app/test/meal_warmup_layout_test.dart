import 'package:fitmakyp/core/models/exercise.dart';
import 'package:fitmakyp/features/habits/domain/hand_portions.dart';
import 'package:fitmakyp/features/habits/ui/meal_sheet.dart';
import 'package:fitmakyp/features/workout/domain/warmup.dart';
import 'package:fitmakyp/features/workout/ui/phase_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('porciones y miniaturas caben en un teléfono angosto', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final moves = cooldownFor(MuscleGroup.values);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ListView(
          children: [
            for (final p in HandPortion.values) PortionRow(portion: p, value: 1.5, onChanged: (_) {}),
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
