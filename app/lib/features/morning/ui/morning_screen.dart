import '../../../core/utils/gender.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../../app_scope.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/hypopressive.dart';
import '../morning_log.dart';

export '../morning_log.dart';
import 'hypo_figure.dart';

String _mins(int seconds) => '~${(seconds / 60).round()} min';

/// Presentación: nivel, posturas y avisos antes de empezar.
class MorningScreen extends StatefulWidget {
  const MorningScreen({super.key});

  @override
  State<MorningScreen> createState() => _MorningScreenState();
}

class _MorningScreenState extends State<MorningScreen> {
  HypoLevel? _level;


  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final store = AppScope.of(context).store;
    final level = _level ??= MorningLog.level(store);
    final doneToday = MorningLog.doneOn(store, DateTime.now());
    final total = MorningLog.total(store);
    return Scaffold(
      appBar: AppBar(title: const Text('Rutina matutina')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                colors: [Color(0xFF2B1B43), Color(0xFF7041B8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('🌅  HIPOPRESIVOS DE PIE', style: TextStyle(color: Color(0xFFDCCBFA), fontWeight: FontWeight.w800, letterSpacing: 1.2, fontSize: 12)),
                const SizedBox(height: 6),
                Text('Empieza el día desde dentro', style: t.headlineSmall?.copyWith(color: Colors.white)),
                const SizedBox(height: 6),
                Text(
                  '${hypoPostures.length} posturas, sin tumbarte. Te guío en cada respiración: inhala, exhala, saca el aire y apnea.',
                  style: t.bodyMedium?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 10),
                Text(
                  doneToday
                      ? '✓ Hecha hoy · $total ${total == 1 ? 'mañana' : 'mañanas'} en total'
                      : total == 0
                          ? 'Mejor en ayunas, al levantarte'
                          : '$total ${total == 1 ? 'mañana' : 'mañanas'} en total',
                  style: t.labelLarge?.copyWith(color: const Color(0xFFDCCBFA)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text('Nivel', style: t.titleMedium),
          const SizedBox(height: 8),
          SegmentedButton<HypoLevel>(
            showSelectedIcon: false,
            segments: [for (final l in HypoLevel.values) ButtonSegment(value: l, label: Text(l.label))],
            selected: {level},
            onSelectionChanged: (v) {
              setState(() => _level = v.first);
              MorningLog.setLevel(store, v.first);
            },
          ),
          const SizedBox(height: 6),
          Text(
            '${level.description}: ${level.reps} apneas de ${level.apnea} s por postura · ${_mins(hypoTotalSeconds(level))}',
            style: t.bodySmall?.copyWith(color: FmColors.muted),
          ),
          const SizedBox(height: 16),
          Text('Las posturas', style: t.titleMedium),
          const SizedBox(height: 8),
          SizedBox(
            height: 150,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: hypoPostures.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (_, i) {
                final p = hypoPostures[i];
                return SizedBox(
                  width: 104,
                  child: Column(
                    children: [
                      Container(
                        height: 108,
                        decoration: BoxDecoration(color: FmColors.lavender, borderRadius: BorderRadius.circular(16)),
                        child: CustomPaint(
                          size: const Size(104, 108),
                          painter: HypoFigurePainter(pose: p.pose, dark: FmColors.dark, bun: !context.isMan),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(context.g(p.name), maxLines: 2, textAlign: TextAlign.center, style: t.labelSmall?.copyWith(height: 1.15)),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('En cada postura', style: t.titleSmall),
                  const SizedBox(height: 6),
                  for (final b in hypoBasics)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text('•  ${context.g(b)}', style: t.bodyMedium),
                    ),
                ],
              ),
            ),
          ),
          Card(
            color: FmColors.dark ? const Color(0xFF3A3020) : const Color(0xFFFFF6DC),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Hazlos en ayunas o 2–3 horas después de comer. Si estás embarazada o en el posparto reciente, '
                'tienes la presión alta, problemas del corazón o respiratorios, o una hernia, consúltalo antes con '
                'un profesional. Si te mareas, para y respira normal.',
                style: t.bodySmall,
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
            onPressed: () async {
              final done = await Navigator.push<bool>(
                context,
                MaterialPageRoute(fullscreenDialog: true, builder: (_) => HypoSessionScreen(level: level)),
              );
              if (done == true) {
                await MorningLog.markDone(store, DateTime.now());
                if (context.mounted) await AppScope.of(context).rewards.refresh();
                if (mounted) setState(() {});
              }
            },
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text(doneToday ? 'REPETIR' : 'EMPEZAR'),
          ),
        ],
      ),
    );
  }
}

/// La guía paso a paso, con la figura animada, voz y vibración.
class HypoSessionScreen extends StatefulWidget {
  const HypoSessionScreen({super.key, required this.level});
  final HypoLevel level;

  @override
  State<HypoSessionScreen> createState() => _HypoSessionScreenState();
}

class _HypoSessionScreenState extends State<HypoSessionScreen> with SingleTickerProviderStateMixin {
  late final List<HypoStep> _steps = buildHypoSteps(widget.level);
  late final Ticker _ticker = createTicker(_onTick);
  int _i = 0;
  double _elapsed = 0;
  double _anim = 0;
  Duration _last = Duration.zero;
  bool _paused = false;
  bool _finished = false;
  int _lastWhole = -1;

  HypoStep get _step => _steps[_i];

  @override
  void initState() {
    super.initState();
    _ticker.start();
    WidgetsBinding.instance.addPostFrameCallback((_) => _announce());
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  bool get _vibrate => AppScope.of(context).settings.settings.vibrationEnabled;

  void _onTick(Duration now) {
    final dt = (now - _last).inMicroseconds / 1e6;
    _last = now;
    if (_paused || _finished || !mounted) return;
    setState(() {
      _anim = (_anim + dt / 1.6) % 1.0;
      _elapsed += dt;
    });
    final left = (_step.seconds - _elapsed).ceil();
    if (left != _lastWhole) {
      _lastWhole = left;
      if (_step.phase == BreathPhase.apnea && left <= 3 && left > 0 && _vibrate) HapticFeedback.selectionClick();
    }
    if (_elapsed >= _step.seconds) _go(_i + 1);
  }

  void _go(int i) {
    if (i < 0) return;
    if (_vibrate) HapticFeedback.lightImpact();
    setState(() {
      if (i >= _steps.length) {
        _finished = true;
        return;
      }
      _i = i;
      _elapsed = 0;
      _lastWhole = -1;
    });
    _announce();
  }

  /// Salta a la postura anterior o siguiente.
  void _jumpPosture(int delta) {
    final target = _step.postureIndex + delta;
    final idx = _steps.indexWhere((s) => s.postureIndex == target);
    if (idx >= 0) _go(idx);
  }

  void _announce() {
    if (!mounted) return;
    final say = AppScope.of(context).workout.say;
    if (_finished) {
      say('¡Rutina completa! Que tengas un gran día.');
      return;
    }
    final s = _step;
    if (s.phase == BreathPhase.prepare) {
      say(context.g('${s.posture.name}. ${s.posture.tips.first}'));
    } else if (s.phase == BreathPhase.apnea) {
      say('${s.phase.spoken}. ${s.seconds} segundos.');
    } else {
      say(s.phase.spoken);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Cerrar',
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context, false),
        ),
        title: const Text('Hipopresivos'),
        actions: [
          if (!_finished) TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Marcar hecha')),
        ],
      ),
      body: SafeArea(top: false, child: _finished ? _done() : _current()),
    );
  }

  Widget _done() {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('🌅', style: TextStyle(fontSize: 72), textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Text('¡Rutina completa!', style: t.headlineSmall, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
            'Bebe un vaso de agua y que tengas un gran día 💜',
            style: t.bodyLarge?.copyWith(color: FmColors.muted),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('LISTO')),
        ],
      ),
    );
  }

  Widget _current() {
    final t = Theme.of(context).textTheme;
    final s = _step;
    final p = s.posture;
    final left = (s.seconds - _elapsed).ceil().clamp(0, s.seconds);
    final shape = breathShapeAt(s.phase, _elapsed, s.seconds);
    final air = switch (s.phase) {
      BreathPhase.inhale || BreathPhase.release => 1,
      BreathPhase.exhale || BreathPhase.emptyOut => -1,
      _ => 0,
    };
    final apnea = s.phase == BreathPhase.apnea;
    final phaseColor = apnea ? const Color(0xFF3FBF9F) : FmColors.primary;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: (_i + _elapsed / s.seconds) / _steps.length,
                  minHeight: 8,
                  backgroundColor: FmColors.line,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Postura ${s.postureIndex + 1} de ${hypoPostures.length}'
                '${s.rep > 0 ? ' · Repetición ${s.rep} de ${widget.level.reps}' : ''}',
                style: t.labelMedium?.copyWith(color: FmColors.muted),
              ),
              const SizedBox(height: 4),
              Text(context.g(p.name), style: t.titleLarge),
              const SizedBox(height: 10),
              Stack(
                children: [
                  Container(
                    height: 280,
                    decoration: BoxDecoration(
                      color: FmColors.lavender.withValues(alpha: FmColors.dark ? 0.5 : 0.6),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: CustomPaint(
                      size: const Size(double.infinity, 280),
                      painter: HypoFigurePainter(
                        pose: p.pose,
                        shape: shape,
                        air: air,
                        anim: _anim,
                        cues: apnea,
                        dark: FmColors.dark,
                        bun: !context.isMan,
                      ),
                    ),
                  ),
                  Positioned(right: 12, top: 12, child: _Countdown(left: left, total: s.seconds, color: phaseColor)),
                  if (s.breath > 0)
                    Positioned(
                      left: 14,
                      top: 14,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(color: FmColors.surface, borderRadius: BorderRadius.circular(20)),
                        child: Text('Respiración ${s.breath} de 3', style: t.labelSmall?.copyWith(color: FmColors.primary, fontWeight: FontWeight.w800)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: Column(
                  key: ValueKey('${s.phase}$_i'),
                  children: [
                    Text(
                      s.phase.label,
                      textAlign: TextAlign.center,
                      style: t.headlineMedium?.copyWith(color: phaseColor, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(s.phase.hint, textAlign: TextAlign.center, style: t.bodyLarge),
                  ],
                ),
              ),
              if (s.phase == BreathPhase.prepare) ...[
                const SizedBox(height: 14),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final (n, tip) in p.tips.indexed)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${n + 1}. ', style: t.bodyMedium?.copyWith(color: FmColors.primary, fontWeight: FontWeight.w700)),
                                Expanded(child: Text(context.g(tip), style: t.bodyMedium)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton.outlined(
                tooltip: 'Postura anterior',
                onPressed: s.postureIndex == 0 ? null : () => _jumpPosture(-1),
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
                tooltip: 'Siguiente postura',
                onPressed: () => s.postureIndex + 1 < hypoPostures.length ? _jumpPosture(1) : _go(_steps.length),
                icon: const Icon(Icons.skip_next_rounded),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Countdown extends StatelessWidget {
  const _Countdown({required this.left, required this.total, required this.color});
  final int left;
  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      width: 76,
      height: 76,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: FmColors.surface,
        shape: BoxShape.circle,
        boxShadow: const [BoxShadow(blurRadius: 10, color: Color(0x22000000))],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CircularProgressIndicator(
            value: total == 0 ? 0 : left / total,
            strokeWidth: 6,
            color: color,
            backgroundColor: FmColors.line,
            strokeCap: StrokeCap.round,
          ),
          Center(
            child: Text(
              '$left',
              style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w800, color: FmColors.ink),
            ),
          ),
        ],
      ),
    );
  }
}
