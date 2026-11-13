import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../models/session.dart';

/// Avisos por voz durante el entrenamiento (voz del sistema, sin internet).
abstract class VoiceCoach {
  Future<void> say(String text);
  Future<void> stop();
}

class NoopVoiceCoach implements VoiceCoach {
  @override
  Future<void> say(String text) async {}
  @override
  Future<void> stop() async {}
}

class TtsVoiceCoach implements VoiceCoach {
  FlutterTts? _tts;

  Future<FlutterTts> _engine() async {
    final existing = _tts;
    if (existing != null) return existing;
    final tts = FlutterTts();
    try {
      // Español; si el teléfono no tiene España, usa el de México o el que haya.
      for (final lang in ['es-ES', 'es-MX', 'es-US', 'es']) {
        if (await tts.isLanguageAvailable(lang) == true) {
          await tts.setLanguage(lang);
          break;
        }
      }
      await tts.setSpeechRate(0.5);
      await tts.setPitch(1.05);
      await tts.awaitSpeakCompletion(false);
    } catch (e) {
      debugPrint('Voz: $e');
    }
    return _tts = tts;
  }

  @override
  Future<void> say(String text) async {
    if (text.trim().isEmpty) return;
    try {
      final tts = await _engine();
      await tts.stop();
      await tts.speak(text);
    } catch (e) {
      debugPrint('Voz: $e');
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _tts?.stop();
    } catch (_) {}
  }
}

/// "1 minuto", "1 minuto y 30 segundos", "45 segundos".
String spokenDuration(int seconds) {
  final m = seconds ~/ 60;
  final s = seconds % 60;
  final mins = m == 0 ? '' : (m == 1 ? '1 minuto' : '$m minutos');
  final secs = s == 0 ? '' : '$s segundos';
  if (mins.isEmpty) return secs.isEmpty ? '0 segundos' : secs;
  return secs.isEmpty ? mins : '$mins y $secs';
}

String _setLine(WorkoutSession s) {
  final ex = s.currentExercise!;
  final planned = ex.plannedSets;
  if (s.currentSet == planned && planned > 1) return 'Última serie de ${ex.name}. ¡Tú puedes!';
  return 'Serie ${s.currentSet} de $planned.';
}

/// Qué decir al pasar de [before] a [after]. null = nada.
String? voiceCue(WorkoutSession before, WorkoutSession after) {
  if (identical(before, after)) return null;
  if (after.status == SessionStatus.completed) {
    return after.finishedEarly ? 'Entrenamiento guardado. ¡Cada serie cuenta!' : '¡Entrenamiento completado! Buen trabajo.';
  }
  if (after.isPaused && !before.isPaused) return 'Pausa.';
  if (before.isPaused && !after.isPaused) return 'Seguimos.';

  final newExercise = after.currentExerciseIndex != before.currentExerciseIndex;
  final ex = after.currentExercise;
  if (ex == null) return null;

  if (before.status == SessionStatus.ready && after.status == SessionStatus.exercise) {
    return 'Empezamos. ${ex.name}. Serie 1 de ${ex.plannedSets}.';
  }
  if (after.status == SessionStatus.resting && before.status == SessionStatus.exercise) {
    final rest = after.rest?.totalSeconds ?? 0;
    final then = newExercise ? ' Después: ${ex.name}.' : '';
    return '¡Bien! Descansa ${spokenDuration(rest)}.$then';
  }
  if (after.status == SessionStatus.exercise &&
      (before.status == SessionStatus.resting || before.status == SessionStatus.exercise)) {
    // El paso al siguiente ejercicio ya se resolvió al entrar en el descanso: la serie 1 lo delata.
    if (newExercise || after.currentSet == 1) return '${ex.name}. Serie 1 de ${ex.plannedSets}.';
    if (after.currentSet != before.currentSet || before.status == SessionStatus.resting) return _setLine(after);
  }
  return null;
}
