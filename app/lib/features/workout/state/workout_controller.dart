import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../../core/models/plan.dart';
import '../../../core/notifications/rest_alarm.dart';
import '../../../core/sound/timer_sounds.dart';
import '../../../core/sound/voice_coach.dart';
import '../../../core/models/session.dart';
import '../../../core/storage/local_store.dart';
import '../../../core/utils/ids.dart';
import '../../history/state/history_repository.dart';
import '../../library/state/library_repository.dart';
import '../../settings/state/settings_repository.dart';
import '../domain/strength.dart';
import '../domain/workout_machine.dart';

/// Peso y reps que se van a anotar en la serie actual.
class SetDraft {
  const SetDraft({this.weight, required this.reps});
  final double? weight;
  final int reps;
}

/// Coordina la sesión en curso: aplica eventos a la máquina de estados,
/// guarda tras cada cambio (para recuperar la sesión si se cierra la app),
/// lleva el reloj del descanso y los recordatorios de agua.
class WorkoutController extends ChangeNotifier {
  // ignore_for_file: prefer_initializing_formals
  WorkoutController({
    required LocalStore store,
    required HistoryRepository history,
    required LibraryRepository library,
    required SettingsRepository settings,
    RestAlarm? alarm,
    TimerSounds? sounds,
    VoiceCoach? voice,
  })  : _store = store,
        _voice = voice ?? NoopVoiceCoach(),
        _history = history,
        _library = library,
        _settings = settings,
        _alarm = alarm ?? NoopRestAlarm(),
        _sounds = sounds ?? NoopTimerSounds() {
    final raw = _store.readJson(_key);
    if (raw is Map<String, dynamic>) {
      try {
        _session = WorkoutSession.fromJson(raw);
      } catch (e) {
        debugPrint('Sesión guardada ilegible, se descarta: $e');
      }
    }
    _lastHydrationAt = DateTime.now();
    _syncTicker();
  }

  static const _key = 'activeSession';
  final LocalStore _store;
  final HistoryRepository _history;
  final LibraryRepository _library;
  final SettingsRepository _settings;
  final RestAlarm _alarm;
  final TimerSounds _sounds;
  final VoiceCoach _voice;
  DateTime? _scheduledRestEnd;

  /// Último segundo de la cuenta atrás que ya sonó (para no repetir el tic).
  int? _lastTickSecond;

  WorkoutSession? _session;
  Timer? _ticker;
  late DateTime _lastHydrationAt;
  bool _hydrationDue = false;

  /// Se actualiza 4 veces por segundo mientras hay una sesión: para los relojes de la UI.
  final ValueNotifier<DateTime> clock = ValueNotifier(DateTime.now());

  WorkoutSession? get session => _session;

  final Map<String, SetDraft> _drafts = {};

  /// Lo que se hizo la última vez en este ejercicio (de otra sesión).
  (WorkoutSession, List<SetPerf>)? lastFor(SessionExercise ex) =>
      lastPerformance(_history.sessions, ex.exerciseId, excludeSessionId: _session?.id);

  ProgressionHint? hintFor(SessionExercise ex) => suggestNext(lastFor(ex)?.$2, ex.target, ex.plannedSets);

  /// Peso y reps propuestos: lo último anotado hoy, o la sugerencia según la última vez.
  SetDraft draftFor(SessionExercise ex) {
    final existing = _drafts[ex.workoutExerciseId];
    if (existing != null) return existing;
    final top = ex.target.max ?? ex.target.min;
    final hint = hintFor(ex);
    return _drafts[ex.workoutExerciseId] = SetDraft(weight: hint?.weight, reps: hint?.reps ?? top);
  }

  void setDraft(SessionExercise ex, SetDraft d) {
    _drafts[ex.workoutExerciseId] = SetDraft(
      weight: d.weight == null || d.weight! <= 0 ? null : d.weight,
      reps: d.reps.clamp(1, 200),
    );
    notifyListeners();
  }
  /// Dice [text] en voz alta si los avisos por voz están activados.
  void say(String text) {
    if (_settings.settings.voiceEnabled) unawaited(_voice.say(text));
  }

  bool get hasActiveSession => _session != null;
  bool get hydrationDue => _hydrationDue;

  /// Crea la sesión del día (estado READY). Si ya había una, la reemplaza.
  Future<void> start(WorkoutPlan plan, WorkoutDay day) async {
    final now = DateTime.now();
    _session = createSession(
      id: newId('ses'),
      planId: plan.id,
      day: day,
      exerciseName: (id) => _library.byId(id)?.name ?? id,
      defaultRestSeconds: _settings.settings.defaultRestSeconds,
      now: now,
    );
    _lastHydrationAt = now;
    _hydrationDue = false;
    _drafts.clear();
    await _save();
    // Se pide al empezar a entrenar, que es cuando tiene sentido.
    unawaited(_alarm.requestPermission());
  }

  /// Guarda qué se hizo con el calentamiento ('done', 'alreadyDone' o 'skipped').
  Future<void> setWarmup(String status) async {
    final s = _session;
    if (s == null) return;
    _session = s.copyWith(warmup: status);
    await _save();
  }

  /// Aplica un evento. Devuelve la sesión terminada si el evento la completó.
  Future<WorkoutSession?> dispatch(WorkoutEvent event) async {
    final current = _session;
    if (current == null) return null;
    final next = reduce(current, event, DateTime.now());
    if (identical(next, current)) return null;
    final cue = voiceCue(current, next);
    if (cue != null) say(cue);

    if (next.status == SessionStatus.completed) {
      _session = null;
      _hydrationDue = false;
      await _history.add(next);
      await _save();
      return next;
    }
    _session = next;
    await _save();
    return null;
  }

  /// Descarta la sesión en curso sin guardarla en el historial.
  Future<void> discard() async {
    _session = null;
    _drafts.clear();
    _hydrationDue = false;
    await _save();
  }

  void dismissHydration() {
    _hydrationDue = false;
    _lastHydrationAt = DateTime.now();
    notifyListeners();
  }

  Future<void> _save() async {
    _syncTicker();
    _syncAlarm();
    notifyListeners();
    await _store.writeJson(_key, _session?.toJson());
  }

  /// Programa (o cancela) el aviso del sistema según el descanso actual.
  void _syncAlarm() {
    final s = _session;
    final rest = s?.rest;
    final DateTime? target =
        (s != null && s.status == SessionStatus.resting && !s.isPaused && rest != null) ? rest.endsAt : null;
    if (target == _scheduledRestEnd) return;
    final previous = _scheduledRestEnd;
    _scheduledRestEnd = target;
    if (target == null) {
      // Si el descanso terminó solo, el aviso ya se mostró: no lo borres.
      final endedNaturally = previous != null && !previous.isAfter(DateTime.now().add(const Duration(seconds: 1)));
      if (!endedNaturally) _alarm.cancel();
    } else {
      final next = s!.currentExercise!;
      _alarm.schedule(target, body: 'Siguiente: ${next.name} · serie ${s.currentSet} de ${next.plannedSets}');
    }
  }

  void _syncTicker() {
    if (_session == null) {
      _ticker?.cancel();
      _ticker = null;
      return;
    }
    _ticker ??= Timer.periodic(const Duration(milliseconds: 250), (_) => _onTick());
  }

  void _onTick() {
    final now = DateTime.now();
    clock.value = now;
    final s = _session;
    if (s == null || s.isPaused) return;

    // Descanso: tic en 3, 2, 1 y sonido final. Nunca durante el ejercicio.
    final rest = s.rest;
    if (s.status == SessionStatus.resting && rest != null) {
      final remaining = rest.remaining(now);
      final secondsLeft = (remaining.inMilliseconds / 1000).ceil();
      if (secondsLeft == 10 && rest.totalSeconds >= 30 && secondsLeft != _lastTickSecond) {
        _lastTickSecond = secondsLeft;
        say('Diez segundos.');
      }
      if (secondsLeft >= 1 && secondsLeft <= 3 && secondsLeft != _lastTickSecond) {
        _lastTickSecond = secondsLeft;
        if (_settings.settings.soundEnabled) _sounds.tick();
      }
      if (remaining == Duration.zero) {
        _lastTickSecond = null;
        _alert();
        dispatch(const FinishRest());
      }
    } else {
      _lastTickSecond = null;
    }

    // Recordatorio de agua.
    final every = _settings.settings.hydrationReminderMinutes;
    if (every > 0 && !_hydrationDue && now.difference(_lastHydrationAt).inMinutes >= every) {
      _hydrationDue = true;
      notifyListeners();
    }
  }

  void _alert() {
    final cfg = _settings.settings;
    if (cfg.vibrationEnabled) HapticFeedback.vibrate();
    if (cfg.soundEnabled) _sounds.restEnd();
  }

  @override
  void dispose() {
    unawaited(_voice.stop());
    _ticker?.cancel();
    clock.dispose();
    super.dispose();
  }
}
