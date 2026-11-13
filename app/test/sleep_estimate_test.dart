import 'package:fitmakyp/features/sleep/domain/sleep_estimate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 11, 13, 9, 30);

  test('el tramo más largo de la noche sin usar el teléfono es el descanso', () {
    final uses = [
      DateTime(2026, 11, 12, 21, 10),
      DateTime(2026, 11, 12, 23, 40), // último uso
      DateTime(2026, 11, 13, 3, 5), // mira la hora un momento
      DateTime(2026, 11, 13, 6, 55), // primera activación
      DateTime(2026, 11, 13, 7, 30),
    ];
    final n = estimateNights(uses, now: now, nights: 1);
    expect(n, hasLength(1));
    expect(n.first.lastUse, DateTime(2026, 11, 13, 3, 5));
    expect(n.first.firstUse, DateTime(2026, 11, 13, 6, 55));
  });

  test('sin despertarse por la noche cuenta toda la noche', () {
    final uses = [DateTime(2026, 11, 12, 23, 0), DateTime(2026, 11, 13, 6, 30), DateTime(2026, 11, 13, 7, 0)];
    final n = estimateNights(uses, now: now, nights: 1).first;
    expect(n.offPhone, const Duration(hours: 7, minutes: 30));
    expect(n.level, RestLevel.bueno);
  });

  test('menos de 2 horas sin teléfono no cuenta como noche', () {
    final uses = [for (var h = 0; h < 20; h++) DateTime(2026, 11, 12, 18).add(Duration(minutes: 90 * h))];
    expect(estimateNights(uses, now: now, nights: 1), isEmpty);
  });

  test('resumen: medias y regularidad', () {
    final nights = [
      NightRest(morning: DateTime(2026, 11, 13), lastUse: DateTime(2026, 11, 12, 23, 0), firstUse: DateTime(2026, 11, 13, 6, 30)),
      NightRest(morning: DateTime(2026, 11, 12), lastUse: DateTime(2026, 11, 12, 0, 30), firstUse: DateTime(2026, 11, 12, 7, 0)),
    ];
    final s = RestSummary(nights);
    expect(s.average, const Duration(hours: 7));
    expect(formatClockMinutes(s.averageWake!), '06:45');
    expect(formatClockMinutes(s.averageLastUse!), '23:45');
    expect(s.wakeSpread, 15);
    expect(formatHm(const Duration(hours: 7, minutes: 5)), '7 h 5 min');
  });
}
