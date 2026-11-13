import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'domain/sleep_estimate.dart';

/// Lee del teléfono (Android) a qué horas se usó, para estimar el descanso.
/// Solo horas: nunca qué apps ni contenido. Nada sale del teléfono.
class SleepService {
  static const _ch = MethodChannel('fitmakyp/launch');

  static bool get supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<bool> hasAccess() async {
    if (!supported) return false;
    try {
      return await _ch.invokeMethod<bool>('usageAccess') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  static Future<void> openSettings() async {
    if (!supported) return;
    try {
      await _ch.invokeMethod<void>('openUsageAccess');
    } on PlatformException catch (e) {
      debugPrint('Ajustes de uso: $e');
    }
  }

  /// Noches recientes (la más reciente primero), o null si no hay permiso.
  static Future<List<NightRest>?> nights({int days = 10}) async {
    if (!supported) return null;
    final now = DateTime.now();
    try {
      final raw = await _ch.invokeListMethod<int>('phoneUses', {
        'from': now.subtract(Duration(days: days + 1)).millisecondsSinceEpoch,
        'to': now.millisecondsSinceEpoch,
      });
      if (raw == null) return null;
      final uses = [for (final ms in raw) DateTime.fromMillisecondsSinceEpoch(ms)];
      return estimateNights(uses, now: now, nights: days);
    } on PlatformException catch (e) {
      debugPrint('Descanso: $e');
      return null;
    } on MissingPluginException {
      return null;
    }
  }
}
