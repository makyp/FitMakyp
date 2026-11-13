import 'dart:io';
import 'dart:ui' as ui;

import 'package:fitmakyp/features/pet/domain/pet_items.dart';
import 'package:fitmakyp/shared/widgets/pet_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cada objeto tiene id único y la ropa nueva existe', () {
    final ids = petItems.map((i) => i.id).toList();
    expect(ids.toSet().length, ids.length);
    expect(petItems.where((i) => i.slot == PetSlot.body).length, greaterThanOrEqualTo(5));
    expect(petItems.where((i) => i.slot == PetSlot.hand).length, greaterThanOrEqualTo(5));
    const look = PetLook();
    expect(look.wearing(PetSlot.body, 'tutu').body, 'tutu');
    expect(look.wearing(PetSlot.hand, 'globo').hand, 'globo');
  });

  testWidgets('la mascota se dibuja con cada objeto y cada acción', (tester) async {
    final looks = [
      for (final i in petItems.where((i) => i.slot != PetSlot.color)) const PetLook().wearing(i.slot, i.id),
    ];
    final key = GlobalKey();
    await tester.pumpWidget(MaterialApp(
      home: RepaintBoundary(
        key: key,
        child: Container(
          color: const Color(0xFFFBF8FF),
          child: Wrap(
            children: [
              for (final l in looks) PetAvatar(size: 90, look: l),
              for (final a in PetAction.values)
                PetAvatar(size: 90, action: a, actionT: 0.3, look: const PetLook(body: 'camiseta', hand: 'mancuerna')),
            ],
          ),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull);
    final out = Platform.environment['FM_PET_OUT'];
    if (out == null) return;
    await tester.runAsync(() async {
      final b = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final img = await b.toImage(pixelRatio: 1);
      final png = await img.toByteData(format: ui.ImageByteFormat.png);
      File(out).writeAsBytesSync(png!.buffer.asUint8List());
    });
  });
}
