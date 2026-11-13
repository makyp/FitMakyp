import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Aviso del sistema al terminar el descanso, aunque la app esté en segundo plano
/// o la pantalla bloqueada. El controlador del entrenamiento solo conoce esta interfaz.
abstract class RestAlarm {
  Future<void> schedule(DateTime at, {required String body});
  Future<void> cancel();

  /// Pide permiso de notificaciones (Android 13+, iOS). Devuelve si está concedido.
  Future<bool> requestPermission();
}

/// Sin avisos (web y pruebas).
class NoopRestAlarm implements RestAlarm {
  @override
  Future<void> schedule(DateTime at, {required String body}) async {}
  @override
  Future<void> cancel() async {}
  @override
  Future<bool> requestPermission() async => false;
}

class LocalNotificationsRestAlarm implements RestAlarm {
  LocalNotificationsRestAlarm._();

  static const _id = 1001;
  static const _channelId = 'rest_timer';
  final _plugin = FlutterLocalNotificationsPlugin();

  static Future<RestAlarm> create() async {
    if (kIsWeb) return NoopRestAlarm();
    try {
      final alarm = LocalNotificationsRestAlarm._();
      tzdata.initializeTimeZones();
      await alarm._plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('ic_stat_fitmakyp'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
      );
      return alarm;
    } catch (e) {
      debugPrint('Notificaciones no disponibles: $e');
      return NoopRestAlarm();
    }
  }

  @override
  Future<bool> requestPermission() async {
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) return await android.requestNotificationsPermission() ?? false;
      final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      if (ios != null) return await ios.requestPermissions(alert: true, sound: true) ?? false;
    } catch (e) {
      debugPrint('Permiso de notificaciones: $e');
    }
    return false;
  }

  @override
  Future<void> schedule(DateTime at, {required String body}) async {
    try {
      await _plugin.cancel(id: _id);
      if (!at.isAfter(DateTime.now())) return;
      await _plugin.zonedSchedule(
        id: _id,
        title: '¡Descanso terminado!',
        body: body,
        scheduledDate: tz.TZDateTime.from(at.toUtc(), tz.UTC),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            'Temporizador de descanso',
            channelDescription: 'Aviso cuando termina el descanso entre series',
            importance: Importance.max,
            priority: Priority.high,
            category: AndroidNotificationCategory.alarm,
            visibility: NotificationVisibility.public,
            enableVibration: true,
            playSound: true,
            icon: 'ic_stat_fitmakyp',
            color: Color(0xFF7041B8),
          ),
          iOS: DarwinNotificationDetails(presentSound: true, interruptionLevel: InterruptionLevel.timeSensitive),
        ),
      );
    } catch (e) {
      debugPrint('No se pudo programar el aviso: $e');
    }
  }

  @override
  Future<void> cancel() async {
    try {
      await _plugin.cancel(id: _id);
    } catch (_) {}
  }
}
