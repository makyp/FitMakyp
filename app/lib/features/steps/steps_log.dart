import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../core/storage/local_store.dart';

/// Pasos por día (copiados del podómetro del teléfono a la app, para puntos, retos y copia de seguridad).
class StepsLog {
  static const _key = 'steps';
  static const _goalKey = 'stepGoal';
  static const _ch = MethodChannel('fitmakyp/launch');

  static bool get supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static String _day(DateTime d) => DateTime(d.year, d.month, d.day).toIso8601String().substring(0, 10);

  static Map<String, int> all(LocalStore s) {
    final raw = s.readJson(_key);
    if (raw is! Map) return {};
    return {for (final e in raw.entries) '${e.key}': (e.value as num?)?.toInt() ?? 0};
  }

  static int on(LocalStore s, DateTime d) => all(s)[_day(d)] ?? 0;

  static int goal(LocalStore s) => (s.readJson(_goalKey) as num?)?.toInt() ?? 8000;
  static Future<void> setGoal(LocalStore s, int g) => s.writeJson(_goalKey, g.clamp(1000, 30000));

  /// Días en que se llegó a la meta de pasos.
  static Set<DateTime> goalDays(LocalStore s) {
    final g = goal(s);
    return {
      for (final e in all(s).entries)
        if (e.value >= g) ?DateTime.tryParse(e.key),
    };
  }

  /// Une lo que trae el podómetro (se queda el mayor por día).
  @visibleForTesting
  static Map<String, int> merge(Map<String, int> a, Map<String, int> b) => {
        ...a,
        for (final e in b.entries) e.key: (a[e.key] ?? 0) > e.value ? a[e.key]! : e.value,
      };

  /// ¿Hay podómetro y permiso?
  static Future<({bool sensor, bool permission})> status() async {
    if (!supported) return (sensor: false, permission: false);
    try {
      final m = await _ch.invokeMapMethod<String, bool>('stepsStatus');
      return (sensor: m?['sensor'] ?? false, permission: m?['permission'] ?? false);
    } on Exception {
      return (sensor: false, permission: false);
    }
  }

  static Future<bool> requestPermission() async {
    if (!supported) return false;
    try {
      return await _ch.invokeMethod<bool>('requestStepsPermission') ?? false;
    } on Exception {
      return false;
    }
  }

  /// Lee el podómetro y guarda. Devuelve true si cambió algo.
  static Future<bool> sync(LocalStore s) async {
    if (!supported) return false;
    try {
      final m = await _ch.invokeMapMethod<String, int>('readSteps');
      if (m == null || m.isEmpty) return false;
      final before = all(s);
      final merged = merge(before, m);
      if (mapEquals(before, merged)) return false;
      await s.writeJson(_key, merged);
      return true;
    } on Exception catch (e) {
      debugPrint('Pasos: $e');
      return false;
    }
  }
}
