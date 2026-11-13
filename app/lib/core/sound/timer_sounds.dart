import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Sonidos del cronómetro de descanso. Nunca se usan durante el ejercicio.
abstract class TimerSounds {
  /// "Tic" de la cuenta atrás (3, 2, 1).
  void tick();

  /// Fin del descanso.
  void restEnd();
}

class NoopTimerSounds implements TimerSounds {
  @override
  void tick() {}
  @override
  void restEnd() {}
}

class AudioTimerSounds implements TimerSounds {
  AudioTimerSounds._();

  final _tick = AudioPlayer();
  final _end = AudioPlayer();

  static Future<TimerSounds> create() async {
    try {
      final s = AudioTimerSounds._();
      // Se mezcla con tu música en vez de pausarla.
      final ctx = AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers).build();
      for (final p in [s._tick, s._end]) {
        await p.setAudioContext(ctx);
        await p.setReleaseMode(ReleaseMode.stop);
      }
      await s._tick.setSource(AssetSource('sounds/tick.wav'));
      await s._end.setSource(AssetSource('sounds/rest_end.wav'));
      return s;
    } catch (e) {
      debugPrint('Sonidos no disponibles: $e');
      return NoopTimerSounds();
    }
  }

  void _play(AudioPlayer p) {
    p.stop().then((_) => p.resume()).catchError((Object e) => debugPrint('Sonido: $e'));
  }

  @override
  void tick() => _play(_tick);

  @override
  void restEnd() => _play(_end);
}

/// Envuelve la creación de los sonidos para no bloquear el inicio: hasta que estén listos, no suenan.
class LazyTimerSounds implements TimerSounds {
  LazyTimerSounds(Future<TimerSounds> Function() create) {
    create().timeout(const Duration(seconds: 10)).then((s) => _inner = s).catchError((Object e) {
      debugPrint('Sonidos no disponibles: $e');
      return _inner;
    });
  }

  TimerSounds _inner = NoopTimerSounds();

  @override
  void tick() => _inner.tick();

  @override
  void restEnd() => _inner.restEnd();
}
