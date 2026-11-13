import '../../../core/utils/gender.dart';
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app_scope.dart';
import '../../../core/models/exercise.dart';
import '../../../core/models/session.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../core/sound/voice_coach.dart';
import '../../../shared/widgets/exercise_media_view.dart';
import '../domain/warmup.dart';

/// Músculos principales que se trabajan en una sesión.
Set<MuscleGroup> sessionMuscles(BuildContext context, WorkoutSession s) {
  final lib = AppScope.of(context).library;
  return {
    for (final e in s.exercises)
      if (lib.byId(e.exerciseId) case final ex?) ex.primaryMuscle,
  };
}

IconData regionIcon(BodyRegion r) => switch (r) {
  BodyRegion.general => Icons.directions_walk_rounded,
  BodyRegion.lower => Icons.accessibility_new_rounded,
  BodyRegion.upper => Icons.sports_gymnastics_rounded,
  BodyRegion.core => Icons.self_improvement_rounded,
};

String _minutes(List<WarmupMove> moves) {
  final m = (totalSeconds(moves) / 60).round().clamp(1, 99);
  return '~$m min';
}

/// Tarjeta de calentamiento o estiramientos con "Hacer", "Ya lo hice" y "Omitir".
class PhaseCard extends StatelessWidget {
  const PhaseCard({
    super.key,
    required this.phase,
    required this.moves,
    required this.status,
    required this.onDo,
    required this.onAlready,
    required this.onSkip,
  });

  final RoutinePhase phase;
  final List<WarmupMove> moves;

  /// Nombre de [PhaseStatus] o null si aún no se decidió.
  final String? status;
  final VoidCallback onDo;
  final VoidCallback onAlready;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final warm = phase == RoutinePhase.warmup;
    final st = status == null ? null : PhaseStatus.values.asNameMap()[status];
    if (st != null) {
      return Card(
        child: ListTile(
          leading: Icon(
            st.counts ? Icons.check_circle_rounded : Icons.remove_circle_outline_rounded,
            color: st.counts ? FmColors.primary : FmColors.muted,
          ),
          title: Text('${phase.label}: ${st.label.toLowerCase()}'),
          trailing: TextButton(onPressed: onDo, child: Text(st == PhaseStatus.done ? 'Repetir' : 'Hacer ahora')),
        ),
      );
    }
    return Card(
      color: FmColors.lavender,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  warm ? Icons.local_fire_department_rounded : Icons.self_improvement_rounded,
                  color: FmColors.primary,
                ),
                const SizedBox(width: 8),
                Expanded(child: Text('${phase.label} · ${_minutes(moves)}', style: t.titleMedium)),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              warm
                  ? 'Prepara músculos y articulaciones para entrenar mejor y con menos riesgo de lesión.'
                  : 'Baja pulsaciones y estira lo que trabajaste hoy. Ayuda a recuperarte.',
              style: t.bodyMedium,
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 112,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: moves.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) => MoveThumb(move: moves[i]),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              onPressed: onDo,
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(warm ? 'CALENTAR AHORA' : 'ESTIRAR AHORA'),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: onAlready,
                    icon: const Icon(Icons.check_rounded),
                    label: Text(warm ? 'Ya calenté' : 'Ya estiré'),
                  ),
                ),
                Expanded(
                  child: TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: FmColors.muted),
                    onPressed: onSkip,
                    icon: const Icon(Icons.skip_next_rounded),
                    label: const Text('Omitir'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Abre la guía. Devuelve true si se completó (o se marcó como hecha).
Future<bool> runPhase(BuildContext context, RoutinePhase phase, List<WarmupMove> moves) async =>
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => PhaseScreen(phase: phase, moves: moves),
      ),
    ) ??
    false;

/// Guía con temporizador: un movimiento tras otro (los de "por lado", un lado y luego el otro).
class PhaseScreen extends StatefulWidget {
  const PhaseScreen({super.key, required this.phase, required this.moves});
  final RoutinePhase phase;
  final List<WarmupMove> moves;

  @override
  State<PhaseScreen> createState() => _PhaseScreenState();
}

class _PhaseScreenState extends State<PhaseScreen> {
  late final List<PhaseStep> _steps = phaseSteps(widget.moves);
  int _i = 0;
  late int _left = _steps.first.seconds;
  bool _paused = false;
  bool _finished = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    WidgetsBinding.instance.addPostFrameCallback((_) => _announce());
  }

  /// Avisos por voz: nombre del movimiento, duración y lado.
  void _announce() {
    if (!mounted) return;
    final workout = AppScope.of(context).workout;
    if (_finished) {
      workout.say(widget.phase == RoutinePhase.warmup ? '¡Cuerpo listo! A entrenar.' : '¡Estiramientos hechos! Buen trabajo.');
      return;
    }
    final step = _steps[_i];
    final side = step.side == null ? '' : ' ${step.side}.';
    workout.say('${step.move.name}.$side ${spokenDuration(step.seconds)}.');
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  bool get _vibrate => AppScope.of(context).settings.settings.vibrationEnabled;

  void _tick() {
    if (_paused || _finished || !mounted) return;
    if (_left > 1) {
      setState(() => _left--);
      if (_left <= 3 && _vibrate) HapticFeedback.selectionClick();
      return;
    }
    _go(_i + 1);
  }

  void _go(int i) {
    if (i < 0) return;
    if (_vibrate) HapticFeedback.mediumImpact();
    setState(() {
      if (i >= _steps.length) {
        _finished = true;
        return;
      }
      _i = i;
      _left = _steps[i].seconds;
    });
    _announce();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final warm = widget.phase == RoutinePhase.warmup;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Cerrar',
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context, false),
        ),
        title: Text(widget.phase.label),
        actions: [
          if (!_finished) TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Marcar hecho')),
        ],
      ),
      body: SafeArea(top: false, child: _finished ? _done(t, warm) : _current(t)),
    );
  }

  Widget _done(TextTheme t, bool warm) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(Icons.check_circle_rounded, size: 88, color: FmColors.primary),
        const SizedBox(height: 16),
        Text(warm ? '¡Cuerpo listo!' : '¡Estiramientos hechos!', style: t.headlineSmall, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text(
          warm ? 'Ahora sí, a entrenar 💪' : 'Tu cuerpo te lo agradece 💜',
          style: t.bodyLarge?.copyWith(color: FmColors.muted),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 28),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(warm ? 'EMPEZAR ENTRENAMIENTO' : 'LISTO'),
        ),
      ],
    ),
  );

  Widget _current(TextTheme t) {
    final step = _steps[_i];
    final m = step.move;
    final next = _i + 1 < _steps.length ? _steps[_i + 1] : null;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: (_i) / _steps.length,
                  minHeight: 8,
                  backgroundColor: FmColors.line,
                ),
              ),
              const SizedBox(height: 6),
              Text('${_i + 1} de ${_steps.length}', style: t.labelMedium?.copyWith(color: FmColors.muted)),
              const SizedBox(height: 12),
              Stack(
                children: [
                  MoveMedia(key: ValueKey(m.id), move: m, height: 250, paused: _paused),
                  Positioned(
                    right: 10,
                    top: 10,
                    child: _TimerBadge(left: _left, total: step.seconds),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(m.name, style: t.headlineSmall, textAlign: TextAlign.center),
              if (step.side != null) ...[
                const SizedBox(height: 6),
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(color: FmColors.lavender, borderRadius: BorderRadius.circular(20)),
                    child: Text(step.side!, style: t.labelLarge?.copyWith(color: FmColors.primary)),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final (n, s) in m.steps.indexed)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${n + 1}. ',
                                style: t.bodyMedium?.copyWith(color: FmColors.primary, fontWeight: FontWeight.w700),
                              ),
                              Expanded(child: Text(context.g(s), style: t.bodyMedium)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        // Controles fijos abajo: siempre en el mismo sitio.
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton.outlined(
                    tooltip: 'Anterior',
                    onPressed: _i == 0 ? null : () => _go(_i - 1),
                    icon: const Icon(Icons.skip_previous_rounded),
                  ),
                  const SizedBox(width: 16),
                  IconButton.filled(
                    iconSize: 36,
                    tooltip: _paused ? 'Seguir' : 'Pausar',
                    onPressed: () => setState(() => _paused = !_paused),
                    icon: Icon(_paused ? Icons.play_arrow_rounded : Icons.pause_rounded),
                  ),
                  const SizedBox(width: 16),
                  IconButton.outlined(
                    tooltip: 'Siguiente',
                    onPressed: () => _go(_i + 1),
                    icon: const Icon(Icons.skip_next_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                next == null
                    ? 'Último movimiento 💪'
                    : 'Siguiente: ${next.move.name}${next.side != null ? ' (${next.side!.toLowerCase()})' : ''}',
                style: t.bodySmall?.copyWith(color: FmColors.muted),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }
}


/// Foto animada del movimiento (inicio y final) o, para la respiración, una burbuja que respira.
class MoveMedia extends StatelessWidget {
  const MoveMedia({super.key, required this.move, this.height = 220, this.paused = false});
  final WarmupMove move;
  final double height;
  final bool paused;

  @override
  Widget build(BuildContext context) {
    if (!move.hasPhoto) return _BreathingOrb(height: height, paused: paused);
    return ExerciseMediaView(
      height: height,
      media: ExerciseMedia(
        kind: MediaKind.imagePair,
        src: move.photoStart,
        endSrc: move.photoEnd,
        alt: move.name,
      ),
    );
  }
}

/// Miniatura con foto y nombre para la tarjeta de calentamiento/estiramientos.
class MoveThumb extends StatelessWidget {
  const MoveThumb({super.key, required this.move});
  final WarmupMove move;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return SizedBox(
      width: 84,
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              width: 84,
              height: 72,
              child: move.hasPhoto
                  ? Image.asset(move.photoEnd, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox())
                  : const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [Color(0xFF9468E0), Color(0xFF7041B8)]),
                      ),
                      child: Center(child: Icon(Icons.air_rounded, color: Colors.white, size: 32)),
                    ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            move.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: t.labelSmall?.copyWith(height: 1.15),
          ),
        ],
      ),
    );
  }
}

class _TimerBadge extends StatelessWidget {
  const _TimerBadge({required this.left, required this.total});
  final int left;
  final int total;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      width: 84,
      height: 84,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: FmColors.surface.withValues(alpha: 0.94),
        shape: BoxShape.circle,
        boxShadow: const [BoxShadow(blurRadius: 10, color: Color(0x33000000))],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CircularProgressIndicator(
            value: left / total,
            strokeWidth: 6,
            backgroundColor: FmColors.line,
            strokeCap: StrokeCap.round,
          ),
          Center(
            child: Text(
              formatClock(Duration(seconds: left)),
              style: t.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: FmColors.ink,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Inhala 4 s, exhala 6 s: la burbuja crece y se encoge.
class _BreathingOrb extends StatefulWidget {
  const _BreathingOrb({required this.height, required this.paused});
  final double height;
  final bool paused;

  @override
  State<_BreathingOrb> createState() => _BreathingOrbState();
}

class _BreathingOrbState extends State<_BreathingOrb> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 10));

  @override
  void initState() {
    super.initState();
    if (!widget.paused) _c.repeat();
  }

  @override
  void didUpdateWidget(_BreathingOrb old) {
    super.didUpdateWidget(old);
    if (widget.paused) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: widget.height,
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2B1B43), Color(0xFF7041B8)],
          ),
        ),
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final v = _c.value;
            final inhale = v < 0.4;
            final p = reduce
                ? 0.5
                : inhale
                    ? Curves.easeInOut.transform(v / 0.4)
                    : 1 - Curves.easeInOut.transform((v - 0.4) / 0.6);
            final size = widget.height * (0.38 + 0.34 * p);
            return Stack(
              alignment: Alignment.center,
              children: [
                for (final k in [1.35, 1.15])
                  Container(
                    width: size * k,
                    height: size * k,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFDCCBFA).withValues(alpha: 0.10 + 0.04 * math.sin(p * math.pi)),
                    ),
                  ),
                Container(
                  width: size,
                  height: size,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [Color(0xFFF1EAFD), Color(0xFFB79AF0)]),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    inhale ? 'Inhala' : 'Exhala',
                    style: t.titleLarge?.copyWith(color: const Color(0xFF2B1B43), fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
