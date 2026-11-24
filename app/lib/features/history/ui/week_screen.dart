import 'package:flutter/material.dart';

import '../../../app_scope.dart';
import '../../../core/models/body.dart';
import '../../../core/models/plan.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../shared/widgets/common.dart';
import '../../workout/ui/summary_screen.dart';
import '../domain/week_insights.dart';

InsightsData insightsData(AppScope s) => InsightsData(
      sessions: s.history.sessions,
      checkins: s.body.checkins,
      records: s.body.records,
      glasses: s.habits.glasses,
      waterGoal: s.habits.settings.waterGoalGlasses,
      habitsDone: (d) => s.habits.activeHabits.where((h) => s.habits.isDone(h.id, d)).length,
      habitsCount: s.habits.activeHabits.length,
    );

const _moods = ['😞', '😕', '😐', '🙂', '😄'];
String _n(int n, String one, String many) => '$n ${n == 1 ? one : many}';
String _moodEmoji(double v) => _moods[(v.round() - 1).clamp(0, 4)];

/// Detalle de una semana: resumen, cada día con todo lo registrado, mejor semana y récords.
class WeekScreen extends StatefulWidget {
  const WeekScreen({super.key, this.initialDay});
  final DateTime? initialDay;

  @override
  State<WeekScreen> createState() => _WeekScreenState();
}

class _WeekScreenState extends State<WeekScreen> {
  late DateTime _monday = mondayOf(widget.initialDay ?? DateTime.now());

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([scope.history, scope.body, scope.habits]),
      builder: (context, _) {
        final t = Theme.of(context).textTheme;
        final data = insightsData(scope);
        final now = DateTime.now();
        final w = weekSummary(data, _monday);
        final bests = personalBests(data, now);
        final isCurrent = _monday == mondayOf(now);
        final sunday = _monday.add(const Duration(days: 6));
        final isBest = bests.activeWeeks >= 2 && bests.bestWeek?.monday == _monday && w.hasActivity;

        return Scaffold(
          appBar: AppBar(title: const Text('Mi semana')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: 'Semana anterior',
                    onPressed: () => setState(() => _monday = _monday.subtract(const Duration(days: 7))),
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(isCurrent ? 'Esta semana' : 'Semana del ${formatShortDate(_monday)}',
                            style: t.titleMedium, textAlign: TextAlign.center),
                        Text('${formatShortDate(_monday)} – ${formatShortDate(sunday)}',
                            style: t.bodySmall?.copyWith(color: FmColors.muted)),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Semana siguiente',
                    onPressed: isCurrent ? null : () => setState(() => _monday = _monday.add(const Duration(days: 7))),
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
              ),
              if (isBest)
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2C14E).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFF2C14E)),
                  ),
                  child: Text('🏆 ¡Esta es tu mejor semana hasta ahora!', style: t.titleSmall),
                ),
              _Summary(w: w, plan: scope.plans.active),
              const SectionTitle('Día a día'),
              for (final d in w.days)
                if (!d.day.isAfter(dateOnly(now)))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _DayCard(d: d, plan: scope.plans.active, waterGoal: w.waterGoal, habitsCount: w.habitsCount),
                  ),
              const SectionTitle('Tus récords'),
              _Bests(
                b: bests,
                onOpenWeek: (m) => setState(() => _monday = m),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.w, required this.plan});
  final WeekSummary w;
  final WorkoutPlan plan;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final planned = plan.days.where((d) => d.isTraining).length;
    Widget avg(String label, double? v, {bool emoji = false}) => Expanded(
          child: Column(
            children: [
              Text(v == null ? '—' : (emoji ? _moodEmoji(v) : v.toStringAsFixed(1)),
                  style: emoji ? const TextStyle(fontSize: 22) : t.titleMedium),
              Text(label, style: t.labelSmall?.copyWith(color: FmColors.muted)),
            ],
          ),
        );
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: StatTile(value: '${w.workouts}/$planned', label: 'Entrenos', highlight: true)),
            const SizedBox(width: 8),
            Expanded(child: StatTile(value: formatDurationShort(w.time), label: 'Entrenando')),
            const SizedBox(width: 8),
            Expanded(child: StatTile(value: '${w.sets}', label: 'Series')),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: StatTile(value: '${w.waterGoalDays}/7', label: 'Días con agua')),
            const SizedBox(width: 8),
            Expanded(
              child: StatTile(
                value: w.habitsPossible == 0 ? '—' : '${(w.habitsDone * 100 / w.habitsPossible).round()} %',
                label: 'Hábitos',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: StatTile(value: '${w.checkins}/7', label: 'Registros diarios')),
          ],
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            child: Column(
              children: [
                Text('Cómo te sentiste (promedio)', style: t.labelLarge),
                const SizedBox(height: 8),
                Row(
                  children: [
                    avg('Ánimo', w.mood, emoji: true),
                    avg('Energía', w.energy),
                    avg('Descanso', w.sleep),
                    avg('Actividad', w.activity),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard({required this.d, required this.plan, required this.waterGoal, required this.habitsCount});
  final DayInsight d;
  final WorkoutPlan plan;
  final int waterGoal;
  final int habitsCount;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final planned = plan.dayForWeekday(d.day.weekday);
    final isToday = d.day == dateOnly(DateTime.now());
    final c = d.checkin;

    Widget line(String emoji, String text) => Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 26, child: Text(emoji, style: const TextStyle(fontSize: 16))),
              Expanded(child: Text(text, style: t.bodyMedium)),
            ],
          ),
        );

    return Card(
      color: d.trained ? FmColors.lavender.withValues(alpha: 0.45) : null,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('${weekdayNames[d.day.weekday - 1]} ${d.day.day}${isToday ? ' · hoy' : ''}', style: t.titleSmall),
                const Spacer(),
                if (d.trained)
                  Icon(Icons.check_circle_rounded, color: FmColors.primary, size: 20)
                else if (planned != null && !planned.isTraining)
                  Text('Descanso', style: t.labelSmall?.copyWith(color: FmColors.muted)),
              ],
            ),
            if (d.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('Sin registros', style: t.bodySmall?.copyWith(color: FmColors.muted)),
              ),
            for (final s in d.sessions.where((s) => s.completedSets > 0))
              InkWell(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SummaryScreen(sessionId: s.id))),
                child: line('🏋️',
                    '${s.dayTitle} · ${formatDurationShort(s.activeDuration(s.finishedAt ?? s.startedAt))} · ${s.completedSets}/${s.plannedSets} series'),
              ),
            if (c != null)
              line(_moods[c.mood - 1],
                  'Ánimo ${c.mood}/5 · energía ${c.energy}/5 · descanso ${c.sleep}/5 · actividad ${c.activity}/5'
                  '${c.comment.isEmpty ? '' : '\n“${c.comment}”'}'),
            if (d.glasses > 0) line('💧', '${d.glasses} de $waterGoal vasos${d.glasses >= waterGoal ? ' ✓' : ''}'),
            if (d.habitsDone > 0) line('✨', '${d.habitsDone} de $habitsCount hábitos'),
            if (d.record != null)
              line('📏', [
                if (d.record!.values[Measure.peso] != null) '${d.record!.values[Measure.peso]} kg',
                if (d.record!.values.length > (d.record!.values[Measure.peso] != null ? 1 : 0))
                  '${d.record!.values.length - (d.record!.values[Measure.peso] != null ? 1 : 0)} medidas',
                if (d.record!.photos.isNotEmpty) '${d.record!.photos.length} 📷',
              ].join(' · ')),
          ],
        ),
      ),
    );
  }
}

class _Bests extends StatelessWidget {
  const _Bests({required this.b, required this.onOpenWeek});
  final PersonalBests b;
  final ValueChanged<DateTime> onOpenWeek;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    String wk(WeekSummary w) => 'Semana del ${formatShortDate(w.monday)}';
    final tiles = <Widget>[
      if (b.bestWeek != null && b.activeWeeks >= 2)
        _best(context, '🏆', 'Tu mejor semana', '${wk(b.bestWeek!)} · ${_n(b.bestWeek!.workouts, 'entreno', 'entrenos')}, '
            '${_n(b.bestWeek!.waterGoalDays, 'día', 'días')} con agua', () => onOpenWeek(b.bestWeek!.monday)),
      if (b.mostWorkoutsWeek != null)
        _best(context, '💪', 'Más entrenamientos', '${wk(b.mostWorkoutsWeek!)} · ${_n(b.mostWorkoutsWeek!.workouts, 'entreno', 'entrenos')}',
            () => onOpenWeek(b.mostWorkoutsWeek!.monday)),
      if (b.bestMoodWeek != null)
        _best(context, _moodEmoji(b.bestMoodWeek!.mood!), 'Semana con mejor ánimo',
            '${wk(b.bestMoodWeek!)} · ánimo ${b.bestMoodWeek!.mood!.toStringAsFixed(1)}/5', () => onOpenWeek(b.bestMoodWeek!.monday)),
      if (b.bestWaterWeek != null)
        _best(context, '💧', 'Mejor semana de agua',
            '${wk(b.bestWaterWeek!)} · ${_n(b.bestWaterWeek!.waterGoalDays, 'día cumplido', 'días cumplidos')}', () => onOpenWeek(b.bestWaterWeek!.monday)),
      if (b.longestWorkout != null)
        _best(
          context,
          '⏱️',
          'Entrenamiento más largo',
          '${formatDurationShort(b.longestWorkout!.activeDuration(b.longestWorkout!.finishedAt ?? b.longestWorkout!.startedAt))} · '
              '${formatShortDate(b.longestWorkout!.startedAt)}',
          () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => SummaryScreen(sessionId: b.longestWorkout!.id))),
        ),
      if (b.mostSetsWorkout != null)
        _best(
          context,
          '🔥',
          'Más series en un día',
          '${_n(b.mostSetsWorkout!.completedSets, 'serie', 'series')} · ${formatShortDate(b.mostSetsWorkout!.startedAt)}',
          () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => SummaryScreen(sessionId: b.mostSetsWorkout!.id))),
        ),
    ];
    if (tiles.isEmpty) {
      return Text('Tus récords aparecerán cuando registres actividad.', style: t.bodyMedium?.copyWith(color: FmColors.muted));
    }
    return Card(child: Column(children: tiles));
  }

  Widget _best(BuildContext context, String emoji, String title, String subtitle, VoidCallback onTap) => ListTile(
        leading: Text(emoji, style: const TextStyle(fontSize: 24)),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      );
}
