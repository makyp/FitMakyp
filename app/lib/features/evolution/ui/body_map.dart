import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/models/body.dart';
import '../domain/muscle_map.dart';

/// Medidas de referencia para lo que no se haya registrado (cm).
const _defaults = <Measure, double>{
  Measure.pecho: 90,
  Measure.cintura: 72,
  Measure.abdomen: 82,
  Measure.cadera: 98,
  Measure.gluteos: 100,
  Measure.musloDer: 56,
  Measure.musloIzq: 56,
  Measure.brazoDer: 28,
  Measure.brazoIzq: 28,
};

/// Anchos vistos de frente (cm) a partir de los perímetros. Un perímetro se aproxima a una elipse:
/// el ancho frontal es aprox. perímetro / 3 (la cadera es más ancha que profunda: / 2,75).
class SilhouetteWidths {
  SilhouetteWidths(Map<Measure, double> v)
      : chest = _w(v, Measure.pecho, 3.0),
        waist = _w(v, Measure.cintura, 3.15),
        abdomen = _w(v, Measure.abdomen, 3.05),
        hips = _w(v, Measure.cadera, 2.75),
        glutes = _w(v, Measure.gluteos, 2.75),
        thighR = _w(v, Measure.musloDer, 3.0),
        thighL = _w(v, Measure.musloIzq, 3.0),
        armR = _w(v, Measure.brazoDer, 3.0),
        armL = _w(v, Measure.brazoIzq, 3.0);

  final double chest, waist, abdomen, hips, glutes, thighR, thighL, armR, armL;

  static double _w(Map<Measure, double> v, Measure m, double k) => (v[m] ?? _defaults[m]!) / k;

  @override
  bool operator ==(Object other) =>
      other is SilhouetteWidths &&
      other.chest == chest &&
      other.waist == waist &&
      other.abdomen == abdomen &&
      other.hips == hips &&
      other.glutes == glutes &&
      other.thighR == thighR &&
      other.thighL == thighL &&
      other.armR == armR &&
      other.armL == armL;

  @override
  int get hashCode => Object.hash(chest, waist, abdomen, hips, glutes, thighR, thighL, armR, armL);
}

/// Una zona concreta del dibujo: [side] es el lado de la persona (-1 derecho, 1 izquierdo, 0 centro).
class ZonePart {
  const ZonePart(this.zone, this.side);
  final BodyZone zone;
  final int side;
}

/// Color de cada zona (null = gris neutro).
typedef ZoneColor = Color? Function(BodyZone zone, int side);

const _skin = Color(0xFFDCD6E3);
const _muscleIdle = Color(0xFFC6BED1);
const _outlineColor = Color(0xFFA197B1);
const _hair = Color(0xFF8C819E);

/// Geometría del cuerpo generada con las medidas, para una vista (frente o espalda).
class BodyGeometry {
  BodyGeometry(this.w, this.size, this.heightCm, this.view) {
    _build();
  }

  final SilhouetteWidths w;
  final Size size;
  final double heightCm;
  final BodyView view;

  late final Path outline;
  late final Path hair;
  final List<(ZonePart, Path)> zones = [];
  final List<Path> details = [];

  late double _cx, _top, _h, _k;

  Offset _p(double xCm, double f) => Offset(_cx + xCm * _k, _top + f * _h);

  // Proporciones derivadas de las medidas (cm, medio ancho).
  double get _chest => w.chest / 2;
  double get _waist => math.min(w.waist / 2, _chest * 0.98);
  double get _abd => w.abdomen / 2;
  double get _hip => math.max(math.max(w.hips, w.glutes) / 2, _waist * 1.02);
  double get _shoulder => math.max(_chest + 0.6, 14.2);

  int _personSide(double s) => (view == BodyView.frente ? s : -s).sign.toInt();
  double _thigh(double s) => _personSide(s) < 0 ? w.thighR : w.thighL;
  double _arm(double s) => _personSide(s) < 0 ? w.armR : w.armL;

  // ---- Piernas: eje y ancho a lo largo de la altura.
  double _legTop(double s) => math.max(_hip - _thigh(s) * 0.5, _thigh(s) * 0.5 + 0.2);
  double _kneeC(double s) => math.max(_thigh(s) * 0.33 + 1.0, 6.5);

  double _legC(double s, double y) {
    final top = _legTop(s), knee = _kneeC(s), ankle = knee * 0.92 + 0.3;
    if (y <= 0.53) return top;
    if (y <= 0.73) return top + (knee - top) * _ease((y - 0.53) / 0.20);
    return knee + (ankle - knee) * ((y - 0.73) / 0.22).clamp(0, 1);
  }

  static const _legWidths = [
    (0.53, 1.0),
    (0.60, 0.9),
    (0.68, 0.7),
    (0.735, 0.56),
    (0.79, 0.63),
    (0.87, 0.42),
    (0.945, 0.3),
  ];

  double _legW(double s, double y) {
    final t = _thigh(s);
    if (y <= _legWidths.first.$1) return t * _legWidths.first.$2;
    for (var i = 0; i < _legWidths.length - 1; i++) {
      final (y0, a) = _legWidths[i];
      final (y1, b) = _legWidths[i + 1];
      if (y <= y1) return t * (a + (b - a) * _ease((y - y0) / (y1 - y0)));
    }
    return t * _legWidths.last.$2;
  }

  // ---- Brazos: eje ligeramente separado del cuerpo.
  double _armX(double s, double y) {
    final j = _shoulder + _arm(s) * 0.18;
    if (y <= 0.19) return j;
    if (y <= 0.37) return j + 3.6 * _ease((y - 0.19) / 0.18 * 0.5 + 0.5) * 2 - 3.6;
    return j + 3.6 + 2.2 * ((y - 0.37) / 0.2).clamp(0, 1);
  }

  static const _armWidths = [
    (0.175, 0.85),
    (0.205, 1.15),
    (0.25, 1.0),
    (0.30, 0.95),
    (0.35, 0.78),
    (0.375, 0.7),
    (0.40, 0.8),
    (0.45, 0.6),
    (0.478, 0.47),
    (0.505, 0.62),
    (0.54, 0.55),
    (0.565, 0.3),
  ];

  double _armW(double s, double y) {
    final a = _arm(s);
    if (y <= _armWidths.first.$1) return a * _armWidths.first.$2;
    for (var i = 0; i < _armWidths.length - 1; i++) {
      final (y0, p) = _armWidths[i];
      final (y1, q) = _armWidths[i + 1];
      if (y <= y1) return a * (p + (q - p) * _ease((y - y0) / (y1 - y0)));
    }
    return a * _armWidths.last.$2;
  }

  static double _ease(double t) => t <= 0 ? 0 : (t >= 1 ? 1 : t * t * (3 - 2 * t));

  void _build() {
    _top = size.height * 0.035;
    _h = size.height * 0.95;
    _cx = size.width / 2;
    _k = _h / heightCm;

    outline = _outline();
    hair = _hairPath();
    if (view == BodyView.frente) {
      _front();
    } else {
      _back();
    }
  }

  Path _outline() {
    // Tronco: lado derecho de la pantalla de arriba abajo; el izquierdo es su reflejo.
    final right = <(double, double)>[
      (4.0, 0.112),
      (4.1, 0.138),
      (5.6, 0.155),
      (_shoulder * 0.6, 0.166),
      (_shoulder, 0.184),
      (_chest + 0.4, 0.215),
      (_chest, 0.25),
      (math.max(_waist, _chest * 0.88), 0.295),
      (_waist, 0.37),
      (_abd, 0.415),
      (_hip, 0.48),
      (_hip * 0.98, 0.52),
      (_hip * 0.9, 0.56),
    ];
    final pts = [for (final (x, y) in right) _p(x, y)];
    final mirror = [for (final o in pts) Offset(2 * _cx - o.dx, o.dy)];
    final torso = Path()..moveTo(mirror.first.dx, mirror.first.dy);
    _smooth(torso, mirror);
    torso.lineTo(_p(0, 0.535).dx, _p(0, 0.535).dy);
    torso.lineTo(pts.last.dx, pts.last.dy);
    _smooth(torso, pts.reversed.toList());
    torso.close();

    final head = Path()..addOval(Rect.fromCenter(center: _p(0, 0.064), width: 14.6 * _k, height: _h * 0.122));
    var out = Path.combine(PathOperation.union, torso, head);

    for (final s in [-1.0, 1.0]) {
      out = Path.combine(PathOperation.union, out, _leg(s));
      out = Path.combine(PathOperation.union, out, _armPath(s));
    }
    return out;
  }

  Path _leg(double s) {
    final ys = [0.53, 0.56, 0.60, 0.65, 0.70, 0.735, 0.765, 0.79, 0.83, 0.87, 0.91, 0.945];
    final outer = [
      _p(s * _hip * 0.97, 0.49),
      for (final y in ys) _p(s * (_legC(s, y) + _legW(s, y) * (y > 0.75 && y < 0.86 ? 0.56 : 0.5)), y),
    ];
    final ankle = _legC(s, 0.945);
    final foot = [
      _p(s * (ankle + 2.9), 0.972),
      _p(s * (ankle + 2.4), 0.996),
      _p(s * (ankle - 2.6), 0.997),
      _p(s * (ankle - 2.9), 0.975),
    ];
    final inner = [
      for (final y in ys.reversed) _p(s * math.max(_legC(s, y) - _legW(s, y) * 0.5, 0.35), y),
      _p(s * 0.35, 0.53),
      _p(s * 0.3, 0.5),
    ];
    final leg = Path()..moveTo(outer.first.dx, outer.first.dy);
    _smooth(leg, outer);
    _smooth(leg, [outer.last, ...foot]);
    _smooth(leg, [foot.last, ...inner]);
    leg.close();
    return leg;
  }

  Path _armPath(double s) {
    final ys = [0.19, 0.205, 0.23, 0.26, 0.30, 0.35, 0.375, 0.40, 0.43, 0.46, 0.478, 0.505, 0.535, 0.553];
    final outer = [for (final y in ys) _p(s * (_armX(s, y) + _armW(s, y) / 2), y)];
    final inner = [for (final y in ys.reversed) _p(s * (_armX(s, y) - _armW(s, y) / 2), y)];
    final tip = _p(s * (_armX(s, 0.568)), 0.568);
    final cap = _p(s * _armX(s, 0.172), 0.171);
    final arm = Path()..moveTo(_p(s * (_armX(s, 0.2) - _arm(s) * 0.45), 0.2).dx, _p(0, 0.2).dy);
    _smooth(arm, [
      _p(s * (_armX(s, 0.2) - _arm(s) * 0.45), 0.2),
      _p(s * (_armX(s, 0.18) - _arm(s) * 0.3), 0.178),
      cap,
      ...outer,
    ]);
    _smooth(arm, [outer.last, tip, ...inner]);
    arm.close();
    return arm;
  }

  Path _hairPath() {
    final bun = Path()..addOval(Rect.fromCircle(center: _p(0, 0.006), radius: 3.4 * _k));
    if (view == BodyView.espalda) {
      final back = Path()
        ..addOval(Rect.fromCenter(center: _p(0, 0.058), width: 14.8 * _k, height: _h * 0.112));
      return Path.combine(PathOperation.union, back, bun);
    }
    final cap = _closed([
      _p(-7.4, 0.082),
      _p(-7.7, 0.045),
      _p(-5.2, 0.014),
      _p(0, 0.004),
      _p(5.2, 0.014),
      _p(7.7, 0.045),
      _p(7.4, 0.082),
      _p(6.3, 0.058),
      _p(3.2, 0.032),
      _p(-1.0, 0.03),
      _p(-5.0, 0.042),
      _p(-6.4, 0.066),
    ]);
    return Path.combine(PathOperation.union, cap, bun);
  }

  // ---------------------------------------------------------------- Vista de frente
  void _front() {
    final a = (_waist * 0.36).clamp(3.0, 5.5);

    _sides(BodyZone.trapecio, (s) => [
          (4.4, 0.146),
          (_shoulder * 0.6, 0.164),
          (_shoulder - 1.4, 0.178),
          (_shoulder * 0.55, 0.18),
          (5.4, 0.163),
        ]);
    _sides(BodyZone.pecho, (s) => [
          (1.0, 0.196),
          (_chest * 0.55, 0.19),
          (_chest * 0.92, 0.205),
          (_chest * 0.98, 0.24),
          (_chest * 0.86, 0.272),
          (_chest * 0.6, 0.288),
          (_chest * 0.3, 0.282),
          (1.2, 0.258),
        ]);

    // Abdomen: recto abdominal con sus "cuadritos" (un solo trazado para los dos lados).
    final abs = Path();
    for (final s in [-1.0, 1.0]) {
      for (final (y0, y1, f) in [(0.292, 0.328, 0.88), (0.333, 0.37, 0.96), (0.375, 0.412, 1.0)]) {
        abs.addRRect(RRect.fromRectAndRadius(
          Rect.fromPoints(_p(s * 0.35, y0), _p(s * a * f, y1)),
          Radius.circular(1.6 * _k),
        ));
      }
      abs.addPath(_closed([_p(s * 0.35, 0.418), _p(s * a, 0.418), _p(s * a * 0.72, 0.458), _p(s * 0.35, 0.476)]), Offset.zero);
    }
    zones.add((const ZonePart(BodyZone.abdomen, 0), abs));

    _sides(BodyZone.oblicuos, (s) => [
          (a + 0.8, 0.31),
          (_chest * 0.82, 0.302),
          (_waist * 0.98, 0.365),
          (_abd * 0.96, 0.415),
          (_hip * 0.74, 0.452),
          (a + 0.9, 0.44),
        ]);

    _arms(front: true);

    _sides(BodyZone.abductores, (s) => [
          (_hip * 0.66, 0.462),
          (_hip * 1.0, 0.478),
          (_hip * 0.98, 0.53),
          (_hip * 0.84, 0.555),
          (_hip * 0.74, 0.5),
        ]);
    _sides(BodyZone.aductores, (s) => [
          (0.4, 0.53),
          (_legC(s, 0.55) - _legW(s, 0.55) * 0.12, 0.548),
          (_legC(s, 0.61) - _legW(s, 0.61) * 0.3, 0.615),
          (_legC(s, 0.67) - _legW(s, 0.67) * 0.4, 0.672),
          (_legC(s, 0.62) - _legW(s, 0.62) * 0.6, 0.62),
          (0.3, 0.56),
        ]);
    _sides(BodyZone.cuadriceps, (s) => [
          (_legC(s, 0.55) - _legW(s, 0.55) * 0.05, 0.543),
          (_legC(s, 0.56) + _legW(s, 0.56) * 0.42, 0.56),
          (_legC(s, 0.64) + _legW(s, 0.64) * 0.45, 0.64),
          (_legC(s, 0.70) + _legW(s, 0.70) * 0.3, 0.703),
          (_legC(s, 0.718), 0.72),
          (_legC(s, 0.70) - _legW(s, 0.70) * 0.36, 0.705),
          (_legC(s, 0.65) - _legW(s, 0.65) * 0.3, 0.64),
          (_legC(s, 0.59) - _legW(s, 0.59) * 0.14, 0.585),
        ]);
    _sides(BodyZone.gemelos, (s) => [
          (_legC(s, 0.76) + _legW(s, 0.76) * 0.08, 0.758),
          (_legC(s, 0.79) + _legW(s, 0.79) * 0.48, 0.79),
          (_legC(s, 0.86) + _legW(s, 0.86) * 0.32, 0.86),
          (_legC(s, 0.9) + _legW(s, 0.9) * 0.08, 0.9),
          (_legC(s, 0.82) - _legW(s, 0.82) * 0.02, 0.82),
        ]);
    _sides(BodyZone.gemelos, (s) => [
          (_legC(s, 0.765) - _legW(s, 0.765) * 0.18, 0.765),
          (_legC(s, 0.8) - _legW(s, 0.8) * 0.56, 0.8),
          (_legC(s, 0.85) - _legW(s, 0.85) * 0.42, 0.85),
          (_legC(s, 0.82) - _legW(s, 0.82) * 0.2, 0.82),
        ]);

    // Detalles: clavículas, rodillas, línea del cuádriceps.
    for (final s in [-1.0, 1.0]) {
      details.add(Path()
        ..moveTo(_p(s * 1.4, 0.176).dx, _p(0, 0.176).dy)
        ..quadraticBezierTo(_p(s * _shoulder * 0.5, 0.168).dx, _p(0, 0.168).dy, _p(s * (_shoulder - 1), 0.177).dx,
            _p(0, 0.177).dy));
      final kc = _p(s * _legC(s, 0.738), 0.738);
      details.add(Path()..addOval(Rect.fromCenter(center: kc, width: _legW(s, 0.738) * _k * 0.55, height: _h * 0.028)));
      details.add(Path()
        ..moveTo(_p(s * (_legC(s, 0.6) + _legW(s, 0.6) * 0.05), 0.6).dx, _p(0, 0.6).dy)
        ..quadraticBezierTo(_p(s * (_legC(s, 0.67) - _legW(s, 0.67) * 0.05), 0.67).dx, _p(0, 0.67).dy,
            _p(s * (_legC(s, 0.71) - _legW(s, 0.71) * 0.12), 0.71).dx, _p(0, 0.71).dy));
    }
  }

  // ---------------------------------------------------------------- Vista de espalda
  void _back() {
    final trap = <(double, double)>[
      (4.2, 0.136),
      (5.6, 0.154),
      (_shoulder * 0.62, 0.166),
      (_shoulder - 0.6, 0.182),
      (_chest * 0.5, 0.215),
      (2.0, 0.272),
      (0.0, 0.312),
    ];
    zones.add((
      const ZonePart(BodyZone.trapecio, 0),
      _closed([
        for (final (x, y) in trap) _p(x, y),
        for (final (x, y) in trap.reversed.skip(1).take(trap.length - 2)) _p(-x, y),
        _p(0, 0.13),
      ]),
    ));
    _sides(BodyZone.dorsales, (s) => [
          (_chest * 0.56, 0.222),
          (_chest * 0.95, 0.225),
          (_chest * 0.97, 0.265),
          (_waist * 0.96, 0.33),
          (_waist * 0.62, 0.368),
          (2.2, 0.383),
          (2.0, 0.3),
          (_chest * 0.38, 0.25),
        ]);
    final lumbar = Path();
    for (final s in [-1.0, 1.0]) {
      lumbar.addPath(
        _closed([_p(s * 0.5, 0.33), _p(s * 3.0, 0.335), _p(s * 3.4, 0.4), _p(s * 2.8, 0.448), _p(s * 0.5, 0.45)]),
        Offset.zero,
      );
    }
    zones.add((const ZonePart(BodyZone.lumbar, 0), lumbar));

    _arms(front: false);

    _sides(BodyZone.abductores, (s) => [
          (_hip * 0.36, 0.452),
          (_hip * 0.8, 0.443),
          (_hip * 1.0, 0.476),
          (_hip * 0.72, 0.474),
        ]);
    _sides(BodyZone.gluteos, (s) => [
          (0.4, 0.468),
          (_hip * 0.55, 0.458),
          (_hip * 0.94, 0.487),
          (_hip * 0.93, 0.533),
          (_hip * 0.62, 0.566),
          (0.6, 0.556),
        ]);
    _sides(BodyZone.isquiotibiales, (s) => [
          (_legC(s, 0.58) - _legW(s, 0.58) * 0.3, 0.578),
          (_legC(s, 0.58) + _legW(s, 0.58) * 0.36, 0.574),
          (_legC(s, 0.65) + _legW(s, 0.65) * 0.4, 0.65),
          (_legC(s, 0.70) + _legW(s, 0.70) * 0.22, 0.708),
          (_legC(s, 0.722), 0.724),
          (_legC(s, 0.70) - _legW(s, 0.70) * 0.26, 0.708),
          (_legC(s, 0.65) - _legW(s, 0.65) * 0.4, 0.65),
        ]);
    _sides(BodyZone.gemelos, (s) => [
          (_legC(s, 0.748) - _legW(s, 0.748) * 0.3, 0.748),
          (_legC(s, 0.748) + _legW(s, 0.748) * 0.3, 0.748),
          (_legC(s, 0.79) + _legW(s, 0.79) * 0.5, 0.79),
          (_legC(s, 0.845) + _legW(s, 0.845) * 0.3, 0.846),
          (_legC(s, 0.875), 0.878),
          (_legC(s, 0.845) - _legW(s, 0.845) * 0.32, 0.846),
          (_legC(s, 0.79) - _legW(s, 0.79) * 0.52, 0.79),
        ]);

    // Detalles: columna, separación de isquios y gemelos, tendón de Aquiles.
    details.add(Path()
      ..moveTo(_p(0, 0.312).dx, _p(0, 0.312).dy)
      ..lineTo(_p(0, 0.46).dx, _p(0, 0.46).dy));
    for (final s in [-1.0, 1.0]) {
      details.add(Path()
        ..moveTo(_p(s * _legC(s, 0.6), 0.6).dx, _p(0, 0.6).dy)
        ..lineTo(_p(s * _legC(s, 0.7), 0.7).dx, _p(0, 0.7).dy));
      details.add(Path()
        ..moveTo(_p(s * _legC(s, 0.76), 0.76).dx, _p(0, 0.76).dy)
        ..lineTo(_p(s * _legC(s, 0.84), 0.84).dx, _p(0, 0.84).dy));
      details.add(Path()
        ..moveTo(_p(s * _legC(s, 0.885), 0.885).dx, _p(0, 0.885).dy)
        ..lineTo(_p(s * _legC(s, 0.94), 0.94).dx, _p(0, 0.94).dy));
    }
  }

  void _arms({required bool front}) {
    _sides(BodyZone.deltoides, (s) {
      final a = _arm(s);
      final x = _armX(s, 0.19);
      return [
        (x - a * 0.62, 0.18),
        (x, 0.171),
        (x + a * 0.58, 0.19),
        (x + a * 0.5, 0.232),
        (x + a * 0.1, 0.256),
        (x - a * 0.4, 0.222),
      ];
    });
    _sides(front ? BodyZone.biceps : BodyZone.triceps, (s) {
      double ax(double y) => _armX(s, y);
      double aw(double y) => _armW(s, y);
      final o = front ? -0.04 : 0.04;
      return [
        (ax(0.23) + aw(0.23) * o, 0.226),
        (ax(0.27) + aw(0.27) * (0.36 + o), 0.268),
        (ax(0.33) + aw(0.33) * (0.32 + o), 0.33),
        (ax(0.358) + aw(0.358) * o, 0.358),
        (ax(0.33) - aw(0.33) * (0.34 - o), 0.33),
        (ax(0.27) - aw(0.27) * (0.36 - o), 0.268),
      ];
    });
    _sides(BodyZone.antebrazos, (s) {
      double ax(double y) => _armX(s, y);
      double aw(double y) => _armW(s, y);
      return [
        (ax(0.385) - aw(0.385) * 0.3, 0.385),
        (ax(0.392) + aw(0.392) * 0.42, 0.392),
        (ax(0.44) + aw(0.44) * 0.3, 0.445),
        (ax(0.468), 0.47),
        (ax(0.44) - aw(0.44) * 0.3, 0.445),
      ];
    });
  }

  /// Añade la zona en los dos lados (puntos en cm desde el centro hacia afuera, para el lado [s]).
  void _sides(BodyZone z, List<(double, double)> Function(double s) pts) {
    for (final s in [-1.0, 1.0]) {
      zones.add((ZonePart(z, _personSide(s)), _closed([for (final (x, y) in pts(s)) _p(s * x, y)])));
    }
  }

  /// Curva suave (Catmull-Rom) que pasa por los puntos, continuando el trazo actual.
  static void _smooth(Path p, List<Offset> pts) {
    p.lineTo(pts.first.dx, pts.first.dy);
    for (var i = 0; i < pts.length - 1; i++) {
      final p0 = i == 0 ? pts[i] : pts[i - 1];
      final p1 = pts[i];
      final p2 = pts[i + 1];
      final p3 = i + 2 < pts.length ? pts[i + 2] : p2;
      final c1 = p1 + (p2 - p0) / 6;
      final c2 = p2 - (p3 - p1) / 6;
      p.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
    }
  }

  /// Contorno cerrado y suave que pasa por todos los puntos.
  static Path _closed(List<Offset> pts) {
    final n = pts.length;
    final p = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 0; i < n; i++) {
      final p0 = pts[(i - 1 + n) % n], p1 = pts[i], p2 = pts[(i + 1) % n], p3 = pts[(i + 2) % n];
      final c1 = p1 + (p2 - p0) / 6;
      final c2 = p2 - (p3 - p1) / 6;
      p.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
    }
    return p..close();
  }

  /// Zona bajo un punto (en coordenadas de esta geometría).
  ZonePart? hit(Offset o) {
    if (!outline.contains(o)) return null;
    for (final (part, path) in zones.reversed) {
      if (path.contains(o)) return part;
    }
    return null;
  }
}

/// Cuerpo con sus músculos, generado con las medidas. Se puede girar (arrastrando o con el botón 360°)
/// para ver frente y espalda, y tocar una zona para ver su detalle.
class BodyMap extends StatefulWidget {
  const BodyMap({
    super.key,
    required this.now,
    this.before,
    this.heightCm = 165,
    this.height = 420,
    required this.colorOf,
    this.onZoneTap,
    this.selected,
    this.interactive = true,
    this.view = BodyView.frente,
  });

  final Map<Measure, double> now;
  final Map<Measure, double>? before;
  final double heightCm;
  final double height;
  final ZoneColor colorOf;
  final void Function(BodyZone zone, int side)? onZoneTap;
  final BodyZone? selected;
  final bool interactive;

  /// Vista inicial (o fija si no es interactivo).
  final BodyView view;

  @override
  State<BodyMap> createState() => _BodyMapState();
}

class _BodyMapState extends State<BodyMap> with SingleTickerProviderStateMixin {
  late final AnimationController _angle = AnimationController.unbounded(
    vsync: this,
    value: widget.view == BodyView.frente ? 0 : math.pi,
  );
  BodyGeometry? _geo;

  @override
  void dispose() {
    _angle.dispose();
    super.dispose();
  }

  BodyView get _view => math.cos(_angle.value) >= 0 ? BodyView.frente : BodyView.espalda;
  double get _scaleX => 0.38 + 0.62 * math.cos(_angle.value).abs();

  void _settle() {
    final target = (_angle.value / math.pi).round() * math.pi;
    _angle.animateTo(target, duration: const Duration(milliseconds: 380), curve: Curves.easeOutCubic);
  }

  void _turnTo(BodyView v) {
    final base = (_angle.value / (2 * math.pi)).round() * 2 * math.pi;
    _angle.animateTo(base + (v == BodyView.frente ? 0 : math.pi),
        duration: const Duration(milliseconds: 650), curve: Curves.easeInOutCubic);
  }

  void _spin() {
    _angle.animateTo((_angle.value / math.pi).round() * math.pi + 2 * math.pi,
        duration: const Duration(milliseconds: 2400), curve: Curves.easeInOutSine);
  }

  void _tap(TapUpDetails d, Size size) {
    final g = _geo;
    if (g == null || widget.onZoneTap == null) return;
    final cx = size.width / 2;
    final p = Offset(cx + (d.localPosition.dx - cx) / _scaleX, d.localPosition.dy);
    final part = g.hit(p);
    if (part != null) widget.onZoneTap!(part.zone, part.side);
  }

  @override
  Widget build(BuildContext context) {
    final map = SizedBox(
      height: widget.height,
      child: LayoutBuilder(
        builder: (context, c) {
          final size = Size(c.maxWidth, widget.height);
          return AnimatedBuilder(
            animation: _angle,
            builder: (context, _) {
              final view = _view;
              final nowW = SilhouetteWidths(widget.now);
              final g = _geo;
              if (g == null || g.view != view || g.size != size || g.w != nowW || g.heightCm != widget.heightCm) {
                _geo = BodyGeometry(nowW, size, widget.heightCm, view);
              }
              final before = widget.before == null
                  ? null
                  : BodyGeometry(SilhouetteWidths(widget.before!), size, widget.heightCm, view).outline;
              final painter = CustomPaint(
                size: size,
                painter: _BodyPainter(
                  geo: _geo!,
                  before: before,
                  colorOf: widget.colorOf,
                  selected: widget.selected,
                  scaleX: _scaleX,
                  light: math.sin(_angle.value),
                ),
              );
              if (!widget.interactive) return painter;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragStart: (_) => _angle.stop(),
                onHorizontalDragUpdate: (d) => _angle.value += d.delta.dx / 95,
                onHorizontalDragEnd: (_) => _settle(),
                onTapUp: (d) => _tap(d, size),
                child: painter,
              );
            },
          );
        },
      ),
    );
    if (!widget.interactive) {
      return Semantics(label: 'Cuerpo visto de ${widget.view.name}', child: map);
    }
    return Semantics(
      label: 'Cuerpo con músculos. Desliza para girarlo; toca un músculo para ver su detalle.',
      child: Column(
        children: [
          map,
          const SizedBox(height: 8),
          AnimatedBuilder(
            animation: _angle,
            builder: (context, _) => Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SegmentedButton<BodyView>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: BodyView.frente, label: Text('Frente')),
                    ButtonSegment(value: BodyView.espalda, label: Text('Espalda')),
                  ],
                  selected: {_view},
                  onSelectionChanged: (v) => _turnTo(v.first),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: 'Girar 360°',
                  onPressed: _spin,
                  icon: const Icon(Icons.threesixty_rounded),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BodyPainter extends CustomPainter {
  _BodyPainter({
    required this.geo,
    required this.before,
    required this.colorOf,
    required this.selected,
    required this.scaleX,
    required this.light,
  });

  final BodyGeometry geo;
  final Path? before;
  final ZoneColor colorOf;
  final BodyZone? selected;
  final double scaleX;

  /// -1..1: de qué lado le da la luz mientras gira.
  final double light;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final big = size.height > 260;
    final bounds = geo.outline.getBounds();

    // Sombra en el suelo.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, bounds.bottom - 1),
        width: bounds.width * 0.75 * scaleX,
        height: size.height * 0.022,
      ),
      Paint()
        ..color = const Color(0xFF2B1B43).withValues(alpha: 0.10)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    canvas.save();
    canvas.translate(cx, 0);
    canvas.scale(scaleX, 1);
    canvas.translate(-cx, 0);

    canvas.drawPath(geo.outline, Paint()..color = _skin);

    canvas.save();
    canvas.clipPath(geo.outline);
    final sep = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = big ? 1.4 : 0.8
      ..strokeJoin = StrokeJoin.round;
    for (final (part, path) in geo.zones) {
      final color = colorOf(part.zone, part.side);
      canvas.drawPath(path, Paint()..color = color ?? _muscleIdle);
      if (color != null) {
        // Brillo suave para dar volumen al músculo.
        final r = path.getBounds();
        canvas.drawPath(
          path,
          Paint()
            ..shader = RadialGradient(
              center: const Alignment(-0.3, -0.4),
              radius: 0.9,
              colors: [Colors.white.withValues(alpha: 0.28), Colors.white.withValues(alpha: 0)],
            ).createShader(r),
        );
      }
      canvas.drawPath(path, sep);
    }
    if (selected != null) {
      final hl = Paint()
        ..color = const Color(0xFF2B1B43)
        ..style = PaintingStyle.stroke
        ..strokeWidth = big ? 2.4 : 1.4;
      for (final (part, path) in geo.zones) {
        if (part.zone == selected) canvas.drawPath(path, hl);
      }
    }
    final detail = Paint()
      ..color = Colors.white.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = big ? 1.1 : 0.7;
    for (final d in geo.details) {
      canvas.drawPath(d, detail);
    }

    // Volumen: sombra hacia los bordes, que se desplaza al girar.
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = LinearGradient(
          colors: [
            const Color(0xFF2B1B43).withValues(alpha: 0.16 + 0.12 * light.clamp(0, 1)),
            const Color(0xFF2B1B43).withValues(alpha: 0),
            const Color(0xFF2B1B43).withValues(alpha: 0),
            const Color(0xFF2B1B43).withValues(alpha: 0.16 + 0.12 * (-light).clamp(0, 1)),
          ],
          stops: [0, (0.3 - 0.15 * light).clamp(0.1, 0.5), (0.7 - 0.15 * light).clamp(0.5, 0.9), 1],
        ).createShader(bounds),
    );
    canvas.restore();

    canvas.drawPath(
      geo.outline,
      Paint()
        ..color = _outlineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = big ? 1.4 : 0.9,
    );
    canvas.drawPath(geo.hair, Paint()..color = _hair);

    if (before != null) {
      _dashed(
        canvas,
        before!,
        Paint()
          ..color = const Color(0xFF2B1B43).withValues(alpha: 0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = big ? 1.6 : 1.0,
        big ? 5 : 3,
      );
    }
    canvas.restore();
  }

  void _dashed(Canvas c, Path path, Paint paint, double dash) {
    for (final m in path.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        c.drawPath(m.extractPath(d, math.min(d + dash, m.length)), paint);
        d += dash * 1.9;
      }
    }
  }

  @override
  bool shouldRepaint(_BodyPainter old) => true;
}
