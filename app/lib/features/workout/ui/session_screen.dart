import '../../../core/utils/gender.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app_scope.dart';
import '../../../core/models/exercise.dart';
import '../../../core/models/session.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/exercise_media_view.dart';
import '../../../shared/widgets/exercise_thumb.dart';
import '../../../shared/widgets/pet_avatar.dart';
import '../domain/strength.dart';
import '../domain/warmup.dart';
import '../domain/workout_machine.dart';
import '../state/workout_controller.dart';
import 'phase_screen.dart';
import 'summary_screen.dart';

/// Ejecución del entrenamiento en tiempo real.
/// Solo pinta el estado y envía eventos al controlador: no contiene reglas de negocio.
class SessionScreen extends StatelessWidget {
  const SessionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context).workout;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final s = controller.session;
        if (s == null) {
          // Instante entre terminar y abrir el resumen, o sesión descartada en otro sitio.
          return Scaffold(
            appBar: AppBar(),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const EmptyHint(icon: Icons.check_circle_outline_rounded, title: 'Sin entrenamiento en curso', text: ''),
                  OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Volver')),
                ],
              ),
            ),
          );
        }
        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              tooltip: 'Salir (se guarda el progreso)',
              icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(s.dayTitle, overflow: TextOverflow.ellipsis),
            actions: [
              if (s.status != SessionStatus.ready)
                IconButton(
                  tooltip: s.isPaused ? 'Reanudar' : 'Pausar',
                  icon: Icon(s.isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded),
                  onPressed: () => _dispatch(context, s.isPaused ? const ResumeWorkout() : const PauseWorkout()),
                ),
              _SessionMenu(session: s),
            ],
          ),
          body: SafeArea(
            top: false,
            child: Column(
              children: [
                _ProgressHeader(session: s, controller: controller),
                if (controller.hydrationDue)
                  _HydrationBanner(onDone: () {
                    controller.dismissHydration();
                    AppScope.of(context).habits.addGlass(DateTime.now());
                  }),
                if (s.isPaused) _PausedBanner(onResume: () => _dispatch(context, const ResumeWorkout())),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    child: switch (s.status) {
                      SessionStatus.ready => _ReadyView(key: const ValueKey('ready'), session: s),
                      SessionStatus.exercise => _ExerciseView(
                          key: ValueKey('ex-${s.currentExerciseIndex}-${s.currentSet}'),
                          session: s,
                        ),
                      SessionStatus.resting => _RestView(key: const ValueKey('rest'), session: s, controller: controller),
                      SessionStatus.completed => const SizedBox.shrink(),
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Envía un evento y, si el entrenamiento terminó, abre el resumen.
Future<void> _dispatch(BuildContext context, WorkoutEvent event) async {
  // Se toma el Navigator ANTES: al terminar, la sesión desaparece y este widget se desmonta.
  final nav = Navigator.of(context);
  final finished = await AppScope.of(context).workout.dispatch(event);
  if (finished != null && nav.mounted) {
    nav.pushReplacement(MaterialPageRoute(builder: (_) => SummaryScreen(sessionId: finished.id)));
  }
}

class _SessionMenu extends StatelessWidget {
  const _SessionMenu({required this.session});
  final WorkoutSession session;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Más opciones',
      onSelected: (v) async {
        switch (v) {
          case 'skip':
            await _dispatch(context, const SkipExercise());
          case 'finish':
            final ok = await _confirm(context, '¿Terminar ahora?',
                'Se guardará lo que llevas hecho (${session.completedSets} ${session.completedSets == 1 ? 'serie' : 'series'}).', 'Terminar');
            if (ok && context.mounted) await _dispatch(context, const FinishEarly());
          case 'discard':
            final ok = await _confirm(
                context, '¿Descartar entrenamiento?', 'No se guardará en tu historial.', 'Descartar');
            if (ok && context.mounted) {
              final nav = Navigator.of(context);
              await AppScope.of(context).workout.discard();
              if (nav.mounted) nav.pop();
            }
        }
      },
      itemBuilder: (_) => [
        if (session.status != SessionStatus.ready)
          const PopupMenuItem(value: 'skip', child: ListTile(leading: Icon(Icons.skip_next_rounded), title: Text('Omitir ejercicio'))),
        const PopupMenuItem(value: 'finish', child: ListTile(leading: Icon(Icons.flag_rounded), title: Text('Terminar ahora'))),
        const PopupMenuItem(
            value: 'discard', child: ListTile(leading: Icon(Icons.delete_outline_rounded), title: Text('Descartar'))),
      ],
    );
  }
}

Future<bool> _confirm(BuildContext context, String title, String body, String action) async =>
    await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(action)),
        ],
      ),
    ) ??
    false;

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({required this.session, required this.controller});
  final WorkoutSession session;
  final WorkoutController controller;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final done = session.completedSets;
    final total = session.plannedSets;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : done / total,
              minHeight: 8,
              backgroundColor: FmColors.line,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text('Ejercicio ${session.currentExerciseIndex + 1} de ${session.exercises.length}',
                  style: t.labelMedium?.copyWith(color: FmColors.muted)),
              const Spacer(),
              Icon(Icons.timer_outlined, size: 14, color: FmColors.muted),
              const SizedBox(width: 4),
              ValueListenableBuilder(
                valueListenable: controller.clock,
                builder: (_, now, _) => Text(
                  session.status == SessionStatus.ready ? '00:00' : formatClock(session.activeDuration(now)),
                  style: t.labelMedium?.copyWith(color: FmColors.muted, fontFeatures: const [FontFeature.tabularFigures()]),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HydrationBanner extends StatelessWidget {
  const _HydrationBanner({required this.onDone});
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        child: Material(
          color: FmColors.mint.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(16),
          child: ListTile(
            leading: const Icon(Icons.water_drop_rounded, color: Color(0xFF2E9E8F)),
            title: const Text('Hora de beber un poco de agua'),
            trailing: TextButton(onPressed: onDone, child: const Text('Bebí un vaso')),
          ),
        ),
      );
}

class _PausedBanner extends StatelessWidget {
  const _PausedBanner({required this.onResume});
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        child: Material(
          color: FmColors.lavender,
          borderRadius: BorderRadius.circular(16),
          child: ListTile(
            leading: Icon(Icons.pause_circle_filled_rounded, color: FmColors.primary),
            title: const Text('Entrenamiento en pausa'),
            trailing: FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
              onPressed: onResume,
              child: const Text('Reanudar'),
            ),
          ),
        ),
      );
}

// ---------------------------------------------------------------- READY

class _ReadyView extends StatelessWidget {
  const _ReadyView({super.key, required this.session});
  final WorkoutSession session;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        const Center(child: MyPet(mood: PetMood.motivating, size: 110)),
        const SizedBox(height: 8),
        Text(context.g('¿Lista? Este es tu entrenamiento de hoy'), style: t.titleLarge, textAlign: TextAlign.center),
        const SizedBox(height: 16),
        // Primero el calentamiento: se ve antes que la lista de ejercicios.
        if (AppScope.of(context).settings.settings.warmupEnabled && session.warmup == null) ...[
          _warmupCard(context),
          const SizedBox(height: 16),
        ],
        Card(
          child: Column(
            children: [
              for (final (i, e) in session.exercises.indexed) ...[
                if (i > 0) const Divider(indent: 16, endIndent: 16),
                ListTile(
                  leading: ExerciseThumb(
                    src: AppScope.of(context).library.byId(e.exerciseId)?.media.src,
                    number: i + 1,
                  ),
                  title: Text(e.name),
                  subtitle: Text('${e.plannedSets} × ${e.target.label} · descanso ${formatClock(Duration(seconds: e.restSeconds))}'),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (!AppScope.of(context).settings.settings.warmupEnabled || session.warmup != null) ...[
          if (session.warmup != null) ...[_warmupCard(context), const SizedBox(height: 12)],
          FilledButton.icon(
            onPressed: () => _dispatch(context, const StartWorkout()),
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('EMPEZAR'),
          ),
        ],
      ],
    );
  }

  /// Calentamiento antes de empezar: al decidir (hacerlo, ya calenté u omitir) arranca el entrenamiento.
  Widget _warmupCard(BuildContext context) {
    final moves = warmupFor(sessionMuscles(context, session));
    final controller = AppScope.of(context).workout;
    Future<void> decide(PhaseStatus st) async {
      await controller.setWarmup(st.name);
      if (context.mounted) await _dispatch(context, const StartWorkout());
    }

    return PhaseCard(
      phase: RoutinePhase.warmup,
      moves: moves,
      status: session.warmup,
      onDo: () async {
        final done = await runPhase(context, RoutinePhase.warmup, moves);
        if (done && context.mounted) await decide(PhaseStatus.done);
      },
      onAlready: () => decide(PhaseStatus.alreadyDone),
      onSkip: () => decide(PhaseStatus.skipped),
    );
  }
}

// ---------------------------------------------------------------- EXERCISE

class _ExerciseView extends StatelessWidget {
  const _ExerciseView({super.key, required this.session});
  final WorkoutSession session;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final ex = session.currentExercise!;
    final found = AppScope.of(context).library.byId(ex.exerciseId);
    final details = found == null ? null : genderExercise(found, context.sex);

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            children: [
              ExerciseMediaView(media: details?.media ?? const ExerciseMedia.none(), height: 240),
              const SizedBox(height: 16),
              Text(ex.name, style: t.headlineSmall),
              if (details != null) ...[
                const SizedBox(height: 4),
                Text(details.description, style: t.bodyMedium?.copyWith(color: FmColors.muted)),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: StatTile(value: '${session.currentSet}/${ex.plannedSets}', label: 'Serie', highlight: true),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: StatTile(value: ex.target.shortValue, label: ex.target.shortUnit)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: StatTile(value: formatClock(Duration(seconds: ex.restSeconds)), label: 'Descanso'),
                  ),
                ],
              ),
              if (!ex.target.isTime) ...[
                const SizedBox(height: 14),
                _LoadCard(ex: ex, paused: session.isPaused),
              ],
              if (ex.target.isTime) ...[
                const SizedBox(height: 14),
                _SetTimer(seconds: ex.target.timerSeconds, paused: session.isPaused),
              ],
              if (details != null && details.instructions.isNotEmpty) ...[
                const SizedBox(height: 14),
                Card(
                  child: Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      shape: const RoundedRectangleBorder(),
                      leading: Icon(Icons.lightbulb_outline_rounded, color: FmColors.primary),
                      title: const Text('Técnica'),
                      childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
                      expandedCrossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (details.startPosition.isNotEmpty) _kv(t, 'Inicio', details.startPosition),
                        if (details.endPosition.isNotEmpty) _kv(t, 'Final', details.endPosition),
                        const SizedBox(height: 6),
                        for (final (i, step) in details.instructions.indexed)
                          Padding(padding: const EdgeInsets.only(bottom: 4), child: Text('${i + 1}. $step')),
                        if (details.commonMistakes.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text('Evita', style: t.labelLarge?.copyWith(color: FmColors.primary)),
                          for (final m in details.commonMistakes) Text('• $m'),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        _CompleteSetBar(session: session),
      ],
    );
  }

  static Widget _kv(TextTheme t, String k, String v) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text.rich(TextSpan(children: [
          TextSpan(text: '$k: ', style: const TextStyle(fontWeight: FontWeight.w800)),
          TextSpan(text: v),
        ])),
      );
}

class _CompleteSetBar extends StatelessWidget {
  const _CompleteSetBar({required this.session});
  final WorkoutSession session;

  @override
  Widget build(BuildContext context) {
    final disabled = session.isPaused;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      decoration: BoxDecoration(
        color: FmColors.surface,
        border: Border(top: BorderSide(color: FmColors.line)),
      ),
      child: Row(
        children: [
          TextButton(
            onPressed: disabled ? null : () => _partial(context),
            child: const Text('Serie\nincompleta', textAlign: TextAlign.center),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SizedBox(
              height: 64,
              child: FilledButton.icon(
                onPressed: disabled
                    ? null
                    : () {
                        HapticFeedback.mediumImpact();
                        final ex = session.currentExercise!;
                        if (ex.target.isTime) {
                          _dispatch(context, const CompleteSet());
                        } else {
                          final d = AppScope.of(context).workout.draftFor(ex);
                          _dispatch(context, CompleteSet(repsDone: d.reps, weightKg: d.weight));
                        }
                      },
                icon: const Icon(Icons.check_rounded, size: 30),
                label: const Text('SERIE COMPLETADA'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _partial(BuildContext context) async {
    final ctrl = TextEditingController();
    final reps = await showDialog<int?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Serie incompleta'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: '¿Cuántas hiciste? (opcional)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, int.tryParse(ctrl.text) ?? -1),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (reps == null || !context.mounted) return;
    final ex = session.currentExercise!;
    final weight = ex.target.isTime ? null : AppScope.of(context).workout.draftFor(ex).weight;
    await _dispatch(context, CompleteSet(result: SetResult.partial, repsDone: reps < 0 ? null : reps, weightKg: weight));
  }
}

/// Cronómetro opcional para series por tiempo (plancha, bicicleta…).
class _SetTimer extends StatefulWidget {
  const _SetTimer({required this.seconds, required this.paused});
  final int seconds;
  final bool paused;

  @override
  State<_SetTimer> createState() => _SetTimerState();
}

class _SetTimerState extends State<_SetTimer> {
  Timer? _timer;
  late int _left = widget.seconds;
  bool _running = false;

  @override
  void didUpdateWidget(_SetTimer old) {
    super.didUpdateWidget(old);
    if (widget.paused && _running) _toggle();
  }

  void _toggle() {
    if (_running) {
      _timer?.cancel();
      setState(() => _running = false);
      return;
    }
    if (_left == 0) _left = widget.seconds;
    setState(() => _running = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() => _left--);
      if (_left <= 0) {
        t.cancel();
        HapticFeedback.vibrate(); // solo vibración: sin sonidos durante el ejercicio
        setState(() {
          _left = 0;
          _running = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(Icons.hourglass_bottom_rounded, color: FmColors.primary),
            const SizedBox(width: 10),
            Text(
              formatClock(Duration(seconds: _left)),
              style: t.headlineSmall?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
            ),
            const Spacer(),
            FilledButton.tonalIcon(
              onPressed: widget.paused ? null : _toggle,
              icon: Icon(_running ? Icons.pause_rounded : Icons.play_arrow_rounded),
              label: Text(_running ? 'Pausar' : (_left == 0 ? 'Repetir' : 'Cronómetro')),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- RESTING

const _restMessages = [
  'Bebe un sorbo de agua.',
  'Respira hondo y suelta los hombros.',
  'Hidrátate: tu cuerpo lo agradece.',
  'Buen trabajo. Recupera el aliento.',
];

class _RestView extends StatelessWidget {
  const _RestView({super.key, required this.session, required this.controller});
  final WorkoutSession session;
  final WorkoutController controller;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final step = AppScope.of(context).settings.settings.restAdjustStepSeconds;
    final next = session.currentExercise!;
    final isNewExercise = session.currentSet == 1;
    final message = _restMessages[session.completedSets % _restMessages.length];

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Text('Tiempo de descanso', style: t.titleLarge, textAlign: TextAlign.center),
        const SizedBox(height: 16),
        Center(
          child: ValueListenableBuilder(
            valueListenable: controller.clock,
            builder: (context, now, _) {
              final rest = session.rest!;
              final remaining = rest.remaining(now);
              final progress = rest.totalSeconds == 0 ? 0.0 : remaining.inMilliseconds / (rest.totalSeconds * 1000);
              return SizedBox(
                width: 240,
                height: 240,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox.expand(
                      child: CircularProgressIndicator(
                        value: progress.clamp(0.0, 1.0),
                        strokeWidth: 12,
                        strokeCap: StrokeCap.round,
                        backgroundColor: FmColors.line,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const MyPet(mood: PetMood.resting, size: 96),
                        Text(
                          formatClock(remaining),
                          style: t.displaySmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: FmColors.ink,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.water_drop_rounded, color: Color(0xFF2E9E8F), size: 18),
            const SizedBox(width: 6),
            Flexible(child: Text(message, style: t.bodyLarge)),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            OutlinedButton(
              onPressed: session.isPaused ? null : () => _dispatch(context, AdjustRest(-step)),
              child: Text('−$step s'),
            ),
            const SizedBox(width: 12),
            IconButton.filledTonal(
              iconSize: 30,
              tooltip: session.isPaused ? 'Reanudar' : 'Pausar',
              onPressed: () => _dispatch(context, session.isPaused ? const ResumeWorkout() : const PauseWorkout()),
              icon: Icon(session.isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded),
            ),
            const SizedBox(width: 12),
            OutlinedButton(
              onPressed: session.isPaused ? null : () => _dispatch(context, AdjustRest(step)),
              child: Text('+$step s'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Card(
          child: ListTile(
            leading: ExerciseThumb(
              src: AppScope.of(context).library.byId(next.exerciseId)?.media.src,
              number: session.currentExerciseIndex + 1,
            ),
            title: Text(isNewExercise ? 'Siguiente ejercicio' : 'Siguiente serie'),
            subtitle: Text('${next.name} · serie ${session.currentSet} de ${next.plannedSets}'),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: session.isPaused ? null : () => _dispatch(context, const FinishRest()),
          child: const Text('CONTINUAR YA'),
        ),
      ],
    );
  }
}

/// Peso y repeticiones de la serie, con lo que se hizo la última vez y la sugerencia para progresar.
class _LoadCard extends StatelessWidget {
  const _LoadCard({required this.ex, required this.paused});
  final SessionExercise ex;
  final bool paused;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final ctrl = AppScope.of(context).workout;
    final d = ctrl.draftFor(ex);
    final last = ctrl.lastFor(ex);
    final hint = ctrl.hintFor(ex);
    final today = [
      for (final x in ex.sets) '${x.repsDone ?? ex.target.min}${x.weightKg == null ? '' : ' × ${formatKg(x.weightKg!)}'}',
    ];

    void setW(double? w) => ctrl.setDraft(ex, SetDraft(weight: w, reps: d.reps));
    void setR(int r) => ctrl.setDraft(ex, SetDraft(weight: d.weight, reps: r));

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: _Stepper(
                    label: 'Peso',
                    value: d.weight == null ? 'Sin peso' : formatKg(d.weight!),
                    enabled: !paused,
                    onMinus: d.weight == null
                        ? null
                        : () => setW(d.weight! <= 1 ? null : d.weight! - weightStep(d.weight! - 0.001)),
                    onPlus: () => setW(d.weight == null ? 1 : d.weight! + weightStep(d.weight!)),
                    onTap: () async {
                      final v = await _askNumber(context, 'Peso (kg)', d.weight, decimal: true);
                      if (v != null) setW(v <= 0 ? null : v);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _Stepper(
                    label: 'Repeticiones',
                    value: '${d.reps}',
                    enabled: !paused,
                    onMinus: d.reps > 1 ? () => setR(d.reps - 1) : null,
                    onPlus: () => setR(d.reps + 1),
                    onTap: () async {
                      final v = await _askNumber(context, 'Repeticiones', d.reps.toDouble());
                      if (v != null && v >= 1) setR(v.round());
                    },
                  ),
                ),
              ],
            ),
            if (today.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Hoy: ${today.join(' · ')}', style: t.bodySmall),
            ],
            if (last != null) ...[
              const SizedBox(height: 6),
              Text(
                'Última vez (${formatShortDate(last.$1.startedAt)}): ${describeSets(last.$2)}',
                style: t.bodySmall?.copyWith(color: FmColors.muted),
              ),
            ],
            if (hint != null) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: hint.increase ? FmColors.lavender : FmColors.warmWhite,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('${hint.increase ? '🚀' : '💡'} ${hint.message}', style: t.bodySmall),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static Future<double?> _askNumber(BuildContext context, String title, double? initial, {bool decimal = false}) {
    final ctrl = TextEditingController(
      text: initial == null ? '' : (initial == initial.roundToDouble() ? '${initial.round()}' : '$initial'),
    );
    return showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.numberWithOptions(decimal: decimal),
          decoration: InputDecoration(hintText: decimal ? '0 = sin peso' : null),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              final v = double.tryParse(ctrl.text.trim().replaceAll(',', '.'));
              if (v != null && v >= 0 && v <= 500) Navigator.pop(ctx, v);
            },
            child: const Text('Listo'),
          ),
        ],
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.label,
    required this.value,
    required this.enabled,
    required this.onMinus,
    required this.onPlus,
    required this.onTap,
  });
  final String label;
  final String value;
  final bool enabled;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(color: FmColors.warmWhite, borderRadius: BorderRadius.circular(16)),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          Text(label, style: t.labelMedium?.copyWith(color: FmColors.muted)),
          Row(
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: enabled ? onMinus : null,
                icon: const Icon(Icons.remove_circle_outline_rounded),
                color: FmColors.primary,
                tooltip: 'Menos',
              ),
              Expanded(
                child: InkWell(
                  onTap: enabled ? onTap : null,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(value, style: t.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                    ),
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: enabled ? onPlus : null,
                icon: const Icon(Icons.add_circle_outline_rounded),
                color: FmColors.primary,
                tooltip: 'Más',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
