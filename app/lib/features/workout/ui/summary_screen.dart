import 'package:flutter/material.dart';

import '../../../app_scope.dart';
import '../../../core/models/session.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/pet_avatar.dart';
import '../../goals/domain/rewards.dart';
import '../domain/strength.dart';
import '../domain/warmup.dart';
import 'phase_screen.dart';

/// Resumen al terminar (también sirve para ver un entrenamiento del historial).
class SummaryScreen extends StatelessWidget {
  const SummaryScreen({super.key, required this.sessionId});
  final String sessionId;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: AppScope.of(context).history,
        builder: (context, _) => _build(context),
      );

  Widget _build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final s = AppScope.of(context).history.byId(sessionId);
    if (s == null) {
      return Scaffold(appBar: AppBar(), body: const Center(child: Text('Entrenamiento no encontrado')));
    }
    final done = s.exercises.where((e) => e.sets.isNotEmpty).length;
    final pct = s.plannedSets == 0 ? 0 : (s.completedSets * 100 / s.plannedSets).round();
    final records = newRecordsIn(s, AppScope.of(context).history.sessions);

    return Scaffold(
      appBar: AppBar(title: const Text('Resumen')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
          const Center(child: MyPet(mood: PetMood.celebrating, size: 130)),
          const SizedBox(height: 8),
          Text(s.finishedEarly ? '¡Bien hecho! Cada serie cuenta.' : '¡Entrenamiento completado!',
              style: t.headlineSmall, textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(s.dayTitle, style: t.bodyMedium?.copyWith(color: FmColors.muted), textAlign: TextAlign.center),
          if (s.completedSets > 0) ...[
            const SizedBox(height: 10),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(color: FmColors.lavender, borderRadius: BorderRadius.circular(20)),
                child: Text(
                  '⭐ +${PointRules.workout + (s.completedSets >= s.plannedSets ? PointRules.fullWorkoutBonus : 0)} puntos para ${AppScope.of(context).pet.name}',
                  style: t.labelLarge?.copyWith(color: FmColors.primary, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
          if (records.isNotEmpty) ...[
            const SizedBox(height: 14),
            Card(
              color: (FmColors.dark ? const Color(0xFF3B3220) : const Color(0xFFFFF6DC)),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(records.length == 1 ? '🏆 ¡Nuevo récord!' : '🏆 ¡${records.length} récords nuevos!',
                        style: t.titleMedium),
                    for (final r in records)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text('${r.exerciseName}: ${r.text}', style: t.bodyMedium),
                      ),
                  ],
                ),
              ),
            ),
          ],
          ..._cooldown(context, s),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: StatTile(value: formatDurationShort(s.activeDuration(DateTime.now())), label: 'Duración')),
              const SizedBox(width: 10),
              Expanded(child: StatTile(value: '$done/${s.exercises.length}', label: 'Ejercicios')),
              const SizedBox(width: 10),
              Expanded(child: StatTile(value: '${s.completedSets}/${s.plannedSets}', label: 'Series')),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(value: pct / 100, minHeight: 10, backgroundColor: FmColors.line),
          ),
          const SizedBox(height: 6),
          Text('$pct % del plan del día', style: t.labelMedium?.copyWith(color: FmColors.muted)),
          if (s.warmup != null || s.cooldown != null) ...[
            const SizedBox(height: 4),
            Text(
              [
                if (PhaseStatus.values.asNameMap()[s.warmup] case final w?) 'Calentamiento: ${w.label.toLowerCase()}',
                if (PhaseStatus.values.asNameMap()[s.cooldown] case final c?) 'Estiramientos: ${c.label.toLowerCase()}',
              ].join(' · '),
              style: t.labelMedium?.copyWith(color: FmColors.muted),
            ),
          ],
          const SectionTitle('Detalle'),
          Card(
            child: Column(
              children: [
                for (final (i, e) in s.exercises.indexed) ...[
                  if (i > 0) const Divider(indent: 16, endIndent: 16),
                  ListTile(
                    title: Text(e.name),
                    subtitle: Text(_detail(e)),
                    trailing: Icon(
                      e.sets.length >= e.plannedSets
                          ? Icons.check_circle_rounded
                          : e.sets.isEmpty
                              ? Icons.remove_circle_outline_rounded
                              : Icons.timelapse_rounded,
                      color: e.sets.length >= e.plannedSets ? FmColors.primary : FmColors.lilac,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(onPressed: () => Navigator.pop(context), child: const Text('LISTO')),
        ],
      ),
    );
  }

  /// Estiramientos al terminar (solo en un entrenamiento recién hecho, o si ya se decidió).
  List<Widget> _cooldown(BuildContext context, WorkoutSession s) {
    final scope = AppScope.of(context);
    final recent = DateTime.now().difference(s.finishedAt ?? s.startedAt).inHours < 12;
    if (!scope.settings.settings.cooldownEnabled || s.completedSets == 0) return const [];
    if (s.cooldown == null && !recent) return const [];
    final moves = cooldownFor(sessionMuscles(context, s));
    Future<void> set(PhaseStatus st) => scope.history.setCooldown(s.id, st.name);
    return [
      const SizedBox(height: 16),
      PhaseCard(
        phase: RoutinePhase.cooldown,
        moves: moves,
        status: s.cooldown,
        onDo: () async {
          if (await runPhase(context, RoutinePhase.cooldown, moves)) await set(PhaseStatus.done);
        },
        onAlready: () => set(PhaseStatus.alreadyDone),
        onSkip: () => set(PhaseStatus.skipped),
      ),
    ];
  }

  static String _detail(SessionExercise e) {
    if (e.sets.isEmpty) return e.skipped ? 'Omitido' : 'Sin series';
    final partial = e.sets.where((x) => x.result == SetResult.partial).length;
    final hasLoad = e.sets.any((x) => x.weightKg != null || x.repsDone != null);
    final perfs = [
      for (final x in e.sets)
        SetPerf(reps: x.repsDone ?? e.target.min, weight: x.weightKg, at: x.finishedAt, sessionId: ''),
    ];
    final base = hasLoad && !e.target.isTime
        ? '${e.sets.length} de ${e.plannedSets} series · ${describeSets(perfs)}'
        : '${e.sets.length} de ${e.plannedSets} series · ${e.target.label}';
    return partial > 0 ? '$base · $partial incompleta${partial > 1 ? 's' : ''}' : base;
  }
}
