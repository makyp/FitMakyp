import 'package:fitmakyp/core/models/exercise.dart';
import 'package:fitmakyp/core/models/session.dart';
import 'package:fitmakyp/core/models/settings.dart';
import 'package:fitmakyp/features/workout/domain/warmup.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('calentamiento según el día: piernas', () {
    final w = warmupFor({MuscleGroup.gluteos, MuscleGroup.cuadriceps});
    final ids = w.map((m) => m.id).toList();
    expect(ids.first, 'marcha', reason: 'empieza con algo general');
    expect(ids, containsAll(['balanceo_piernas', 'sentadilla_aire', 'puente_activacion']));
    expect(ids, isNot(contains('flexion_pared')));
    final mins = totalSeconds(w) / 60;
    expect(mins, inInclusiveRange(3, 8));
  });

  test('calentamiento según el día: tren superior', () {
    final ids = warmupFor({MuscleGroup.pecho, MuscleGroup.triceps}).map((m) => m.id);
    expect(ids, containsAll(['circulos_brazos', 'flexion_pared']));
    expect(ids, isNot(contains('sentadilla_aire')));
  });

  test('estiramientos de lo trabajado y respiración al final', () {
    final c = cooldownFor({MuscleGroup.gluteos, MuscleGroup.aductores});
    expect(c.map((m) => m.id), containsAll(['est_cuadriceps', 'est_gluteo', 'est_mariposa']));
    expect(c.last.id, 'respiracion');
    final full = cooldownFor({MuscleGroup.pecho, MuscleGroup.cuadriceps});
    expect(totalSeconds(full) / 60, inInclusiveRange(3, 9));
    expect(cooldownFor(const <MuscleGroup>{}), isNotEmpty);
  });

  test('los movimientos por lado se hacen en dos pasos', () {
    final steps = phaseSteps(cooldownFor({MuscleGroup.cuadriceps}));
    final quad = steps.where((s) => s.move.id == 'est_cuadriceps').toList();
    expect(quad.map((s) => s.side), ['Lado derecho', 'Lado izquierdo']);
  });

  test('se guarda si calentaste y estiraste', () {
    final s = WorkoutSession(
      id: 's',
      planId: 'p',
      dayId: 'd',
      dayTitle: 'Día',
      status: SessionStatus.ready,
      exercises: const [],
      startedAt: DateTime.utc(2026, 11, 10),
    ).copyWith(warmup: PhaseStatus.alreadyDone.name, cooldown: PhaseStatus.skipped.name);
    final back = WorkoutSession.fromJson(s.toJson());
    expect(back.warmup, 'alreadyDone');
    expect(back.cooldown, 'skipped');
    expect(AppSettings.fromJson(const {}).warmupEnabled, isTrue);
    expect(AppSettings.fromJson(const AppSettings(cooldownEnabled: false).toJson()).cooldownEnabled, isFalse);
  });
}
