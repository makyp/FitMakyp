import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../core/models/plan.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/pet_avatar.dart';
import '../goals/ui/goals_screen.dart';
import '../habits/ui/habits_screen.dart';
import '../habits/ui/meal_sheet.dart';
import '../challenges/challenges_screen.dart';
import '../challenges/domain/challenges.dart';
import '../cycle/cycle_screen.dart';
import '../steps/steps_log.dart';
import '../summary/month_summary_screen.dart';
import '../cycle/cycle_store.dart';
import '../morning/ui/morning_screen.dart';
import '../sleep/domain/sleep_estimate.dart';
import '../sleep/sleep_screen.dart';
import '../sleep/sleep_service.dart';
import '../history/ui/week_screen.dart';
import '../workout/ui/start_workout.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.onOpenTab});

  final ValueChanged<int> onOpenTab;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([scope.plans, scope.history, scope.workout, scope.settings, scope.rewards, scope.pet, scope.body, scope.habits]),
      builder: (context, _) {
        final now = DateTime.now();
        final t = Theme.of(context).textTheme;
        final today = scope.plans.today;
        final active = scope.workout.session;
        final trainingWeekdays = scope.plans.trainingWeekdays;
        final streak = scope.history.streak(trainingWeekdays);
        final trained = scope.history.trainedDates;
        final trainedToday = trained.contains(dateOnly(now));

        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              Text(formatLongDate(now).toUpperCase(),
                  style: t.labelMedium?.copyWith(color: FmColors.muted, letterSpacing: 1.2)),
              const SizedBox(height: 4),
              Text(
                scope.settings.settings.userName.trim().isEmpty
                    ? greeting(now)
                    : '${greeting(now)}, ${scope.settings.settings.userName}',
                style: t.headlineMedium,
              ),
              const SizedBox(height: 20),
              _TodayCard(day: today, activeTitle: active?.dayTitle, trainedToday: trainedToday),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: StatTile(value: '${streak.current}', label: 'Racha actual')),
                  const SizedBox(width: 10),
                  Expanded(child: StatTile(value: '${streak.best}', label: 'Mejor racha')),
                  const SizedBox(width: 10),
                  Expanded(
                    child: StatTile(
                      value: '${_doneThisWeek(trained, now)}/${trainingWeekdays.length}',
                      label: 'Esta semana',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (now.hour < 12) const _MorningCard(),
              if (now.day <= 3) ...[
                Card(
                  color: FmColors.lavender,
                  child: ListTile(
                    leading: const Text('🗓️', style: TextStyle(fontSize: 26)),
                    title: Text('Tu resumen del mes está listo', style: TextStyle(color: FmColors.ink, fontWeight: FontWeight.w700)),
                    subtitle: Text('Mira todo lo que lograste', style: TextStyle(color: FmColors.ink)),
                    trailing: Icon(Icons.chevron_right_rounded, color: FmColors.ink),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MonthSummaryScreen())),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              const _TodayHabitsCard(),
              if (StepsLog.supported) const _StepsCard(),
              const SizedBox(height: 12),
              const _ChallengesCard(),
              if (AppScope.of(context).habits.settings.nutritionEnabled) ...[
                const SizedBox(height: 12),
                const _TodayMealsCard(),
              ],
              if (SleepService.supported) ...[
                const SizedBox(height: 12),
                const _RestCard(),
              ],
              if (scope.settings.settings.showCycle) ...[
                const SizedBox(height: 12),
                const _CycleCard(),
              ],
              SectionTitle('Tu semana',
                  trailing: TextButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WeekScreen())),
                    child: const Text('Ver más'),
                  )),
              _WeekStrip(plan: scope.plans.active, trained: trained, now: now),
              const SectionTitle('Tu mascota'),
              Card(
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: () => onOpenTab(3),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        MyPet(
                          size: 84,
                          mood: trainedToday
                              ? PetMood.happy
                              : (today?.isTraining ?? false)
                                  ? PetMood.motivating
                                  : PetMood.resting,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(scope.pet.name, style: t.titleMedium),
                                  const Spacer(),
                                  Text('Nv. ${scope.rewards.level} · ⭐ ${scope.rewards.balance}',
                                      style: t.labelMedium?.copyWith(color: FmColors.primary, fontWeight: FontWeight.w800)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _petMessage(trainedToday: trainedToday, isTrainingDay: today?.isTraining ?? false),
                                style: t.bodyMedium?.copyWith(color: FmColors.muted),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SectionTitle('Próxima evaluación corporal'),
              Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                  leading: Icon(Icons.straighten_rounded, color: FmColors.primary),
                  title: Text(switch (scope.body.daysToEvaluation(now)) {
                    null => 'Haz tu primera evaluación',
                    final d when d <= 0 => '¡Te toca hoy!',
                    1 => 'Mañana',
                    final d => 'En $d días',
                  }),
                  subtitle: const Text('Peso, medidas y fotos'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => onOpenTab(2),
                ),
              ),
              SectionTitle('Mis metas',
                  trailing: TextButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GoalsScreen())),
                    child: Text(scope.goals.active.isEmpty ? 'Crear' : 'Ver todas'),
                  )),
              if (scope.goals.active.isEmpty)
                Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                    leading: Icon(Icons.flag_outlined, color: FmColors.primary),
                    title: const Text('Ponte una meta'),
                    subtitle: const Text('Un peso, una medida, días seguidos… y gana puntos'),
                    onTap: () => showAddGoalSheet(context),
                  ),
                )
              else
                for (final g in scope.goals.active.take(2))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: GoalCard(goal: g, progress: scope.rewards.progressOf(g), compact: true),
                  ),
            ],
          ),
        );
      },
    );
  }

  static int _doneThisWeek(Set<DateTime> trained, DateTime now) {
    final monday = dateOnly(now).subtract(Duration(days: now.weekday - 1));
    return trained.where((d) => !d.isBefore(monday) && !d.isAfter(dateOnly(now))).length;
  }

  static String _petMessage({required bool trainedToday, required bool isTrainingDay}) {
    if (trainedToday) return '¡Entrenamiento hecho! Estoy muy orgullosa de ti.';
    if (isTrainingDay) return 'Hoy toca entrenar. ¡Vamos juntas!';
    return 'Hoy es día de recuperación. Descansar también es progresar.';
  }
}

class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.day, required this.activeTitle, required this.trainedToday});
  final WorkoutDay? day;
  final String? activeTitle;
  final bool trainedToday;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final d = day;
    final training = d != null && d.isTraining && d.activeExercises.isNotEmpty;
    final exercises = d?.activeExercises ?? const [];
    final sets = exercises.fold<int>(0, (a, e) => a + e.sets);

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [FmColors.deep, FmColors.primary],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            activeTitle != null ? 'EN CURSO' : 'HOY',
            style: t.labelMedium?.copyWith(color: const Color(0xFFDCCBFA), letterSpacing: 1.4, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            activeTitle ?? (training ? d.title : (d?.title ?? 'Sin plan para hoy')),
            style: t.headlineSmall?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 6),
          Text(
            activeTitle != null
                ? 'Retoma donde lo dejaste.'
                : training
                    ? '${exercises.length} ejercicios · $sets series${trainedToday ? ' · ¡ya entrenaste hoy!' : ''}'
                    : 'Día de recuperación. Estira, camina o descansa.',
            style: t.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.8)),
          ),
          if (training || activeTitle != null) ...[
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: FmColors.primary),
                onPressed: () {
                  if (activeTitle != null) {
                    openSession(context);
                  } else {
                    startWorkout(context, d!);
                  }
                },
                icon: Icon(activeTitle != null ? Icons.play_circle_fill_rounded : Icons.play_arrow_rounded),
                label: Text(activeTitle != null ? 'CONTINUAR ENTRENAMIENTO' : 'INICIAR ENTRENAMIENTO'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _WeekStrip extends StatelessWidget {
  const _WeekStrip({required this.plan, required this.trained, required this.now});
  final WorkoutPlan plan;
  final Set<DateTime> trained;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final monday = dateOnly(now).subtract(Duration(days: now.weekday - 1));
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            for (var i = 0; i < 7; i++)
              Builder(builder: (context) {
                final date = monday.add(Duration(days: i));
                final day = plan.dayForWeekday(i + 1);
                final done = trained.contains(date);
                final isToday = date == dateOnly(now);
                final isRest = day == null || !day.isTraining;
                final Color bg = done
                    ? FmColors.primary
                    : isRest
                        ? FmColors.warmWhite
                        : FmColors.lavender.withValues(alpha: 0.5);
                return Column(
                  children: [
                    Text(weekdayNames[i].substring(0, 1),
                        style: t.labelMedium?.copyWith(
                          color: isToday ? FmColors.primary : FmColors.muted,
                          fontWeight: isToday ? FontWeight.w900 : FontWeight.w600,
                        )),
                    const SizedBox(height: 8),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: bg,
                        shape: BoxShape.circle,
                        border: isToday ? Border.all(color: FmColors.primary, width: 2) : null,
                      ),
                      child: Icon(
                        done ? Icons.check_rounded : (isRest ? Icons.spa_outlined : Icons.fitness_center_rounded),
                        size: 16,
                        color: done ? Colors.white : FmColors.lilac,
                      ),
                    ),
                  ],
                );
              }),
          ],
        ),
      ),
    );
  }
}

/// Agua y hábitos de hoy, con acceso rápido.
class _TodayHabitsCard extends StatelessWidget {
  const _TodayHabitsCard();

  @override
  Widget build(BuildContext context) {
    final h = AppScope.of(context).habits;
    final t = Theme.of(context).textTheme;
    final now = DateTime.now();
    final n = h.glasses(now);
    final goal = h.settings.waterGoalGlasses;
    final habits = h.activeHabits;
    final done = habits.where((x) => h.isDone(x.id, now)).length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HabitsScreen())),
                child: Row(
                  children: [
                    SizedBox(
                      width: 46,
                      height: 46,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CircularProgressIndicator(
                            value: (n / goal).clamp(0.0, 1.0),
                            strokeWidth: 5,
                            backgroundColor: FmColors.line,
                            color: const Color(0xFF4FB3D9),
                          ),
                          const Text('💧', style: TextStyle(fontSize: 18)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Agua: $n / $goal vasos', style: t.titleSmall),
                          Text(
                            habits.isEmpty ? 'Toca para ver tus hábitos' : 'Hábitos: $done / ${habits.length}',
                            style: t.bodySmall?.copyWith(color: FmColors.muted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            IconButton.filledTonal(
              tooltip: 'Sumar un vaso de agua',
              onPressed: () => h.addGlass(now),
              icon: const Icon(Icons.add_rounded),
            ),
          ],
        ),
      ),
    );
  }
}


/// Comidas de hoy, a la vista y con "+" para añadir rápido.
class _TodayMealsCard extends StatelessWidget {
  const _TodayMealsCard();

  @override
  Widget build(BuildContext context) {
    final h = AppScope.of(context).habits;
    final t = Theme.of(context).textTheme;
    final now = DateTime.now();
    final meals = h.mealsOn(now);
    final protein = h.proteinOn(now);
    final target = h.settings.proteinTarget;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HabitsScreen(initialTab: 1))),
                child: Row(
                  children: [
                    SizedBox(
                      width: 46,
                      height: 46,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CircularProgressIndicator(
                            value: target == 0 ? 0 : (protein / target).clamp(0.0, 1.0),
                            strokeWidth: 5,
                            backgroundColor: FmColors.line,
                            color: const Color(0xFFE59A5C),
                          ),
                          const Text('🍽️', style: TextStyle(fontSize: 18)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            meals.isEmpty
                                ? 'Comidas de hoy'
                                : 'Comidas: ${meals.length} ${meals.length == 1 ? 'registrada' : 'registradas'}',
                            style: t.titleSmall,
                          ),
                          Text(
                            meals.isEmpty
                                ? 'Apúntalas con tu mano, sin pesar nada ✋'
                                : 'Proteína ≈ $protein / $target g (orientativo)',
                            style: t.bodySmall?.copyWith(color: FmColors.muted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            IconButton.filledTonal(
              tooltip: 'Añadir comida',
              onPressed: () => showMealSheet(context, day: now),
              icon: const Icon(Icons.add_rounded),
            ),
          ],
        ),
      ),
    );
  }
}


/// Por la mañana, si aún no se hizo, invita a la rutina matutina.
class _MorningCard extends StatefulWidget {
  const _MorningCard();

  @override
  State<_MorningCard> createState() => _MorningCardState();
}

class _MorningCardState extends State<_MorningCard> {
  @override
  Widget build(BuildContext context) {
    if (MorningLog.doneOn(AppScope.of(context).store, DateTime.now())) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        color: FmColors.lavender,
        child: ListTile(
          leading: const Text('🌅', style: TextStyle(fontSize: 26)),
          title: Text('Rutina matutina', style: TextStyle(color: FmColors.ink, fontWeight: FontWeight.w700)),
          subtitle: Text('Hipopresivos de pie, en ayunas', style: TextStyle(color: FmColors.ink)),
          trailing: Icon(Icons.play_circle_fill_rounded, color: FmColors.primary, size: 34),
          onTap: () async {
            await Navigator.push(context, MaterialPageRoute(builder: (_) => const MorningScreen()));
            if (mounted) setState(() {});
          },
        ),
      ),
    );
  }
}


/// Descanso de anoche (estimado por el uso del teléfono).
class _RestCard extends StatefulWidget {
  const _RestCard();

  @override
  State<_RestCard> createState() => _RestCardState();
}

class _RestCardState extends State<_RestCard> {
  bool? _access;
  NightRest? _last;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final access = await SleepService.hasAccess();
    final nights = access ? await SleepService.nights(days: 1) : null;
    if (!mounted) return;
    setState(() {
      _access = access;
      _last = (nights == null || nights.isEmpty) ? null : nights.first;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final last = _last;
    return Card(
      child: ListTile(
        leading: Container(
          width: 46,
          height: 46,
          alignment: Alignment.center,
          decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF2B1B43)),
          child: const Text('🌙', style: TextStyle(fontSize: 20)),
        ),
        title: Text(last == null ? 'Mi descanso' : 'Anoche: ${formatHm(last.offPhone)} sin teléfono', style: t.titleSmall),
        subtitle: Text(
          _access == false
              ? 'Actívalo para ver cómo descansas'
              : last == null
                  ? 'Aún sin datos de anoche'
                  : '☀️ Primera activación ${formatTime(last.firstUse)} · ${last.level.label}',
          style: t.bodySmall?.copyWith(color: FmColors.muted),
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const SleepScreen()));
          _load();
        },
      ),
    );
  }
}


/// Día y fase del ciclo (si está activado en Perfil).
class _CycleCard extends StatefulWidget {
  const _CycleCard();

  @override
  State<_CycleCard> createState() => _CycleCardState();
}

class _CycleCardState extends State<_CycleCard> {
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final st = CycleStore(AppScope.of(context).store).status;
    final now = DateTime.now();
    final phase = st.phaseOn(now);
    final day = st.cycleDay(now);
    final until = st.daysUntilNext(now);
    final inPeriod = st.periodOn(now) != null;
    return Card(
      child: ListTile(
        leading: Container(
          width: 46,
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(shape: BoxShape.circle, color: (phase?.color ?? FmColors.primary).withValues(alpha: 0.2)),
          child: Text(phase?.emoji ?? '🌸', style: const TextStyle(fontSize: 20)),
        ),
        title: Text(day == null ? 'Mi ciclo' : 'Día $day · ${phase?.label ?? ''}', style: t.titleSmall),
        subtitle: Text(
          day == null
              ? 'Registra tu última regla'
              : inPeriod
                  ? 'Toca para anotar flujo y síntomas'
                  : until == null
                      ? ''
                      : until >= 0
                          ? 'Próxima regla en ~$until ${until == 1 ? 'día' : 'días'}'
                          : 'Retraso de ${-until} ${-until == 1 ? 'día' : 'días'}',
          style: t.bodySmall?.copyWith(color: FmColors.muted),
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const CycleScreen()));
          if (mounted) setState(() {});
        },
      ),
    );
  }
}


/// Retos de la semana en pequeño.
class _ChallengesCard extends StatelessWidget {
  const _ChallengesCard();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scope = AppScope.of(context);
    final week = weekStatus(weekStart(DateTime.now()), scope.rewards.challenges);
    final done = week.where((s) => s.done).length;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChallengesScreen())),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('🏆 Retos de la semana', style: t.titleSmall),
                  const Spacer(),
                  Text(done == week.length ? '¡Semana perfecta!' : '$done/${week.length}',
                      style: t.labelLarge?.copyWith(color: FmColors.primary)),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
              const SizedBox(height: 4),
              for (final s in week) ChallengeTile(status: s, compact: true),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pasos de hoy con el podómetro del teléfono.
class _StepsCard extends StatefulWidget {
  const _StepsCard();

  @override
  State<_StepsCard> createState() => _StepsCardState();
}

class _StepsCardState extends State<_StepsCard> {
  ({bool sensor, bool permission})? _status;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await StepsLog.status();
    if (!mounted) return;
    setState(() => _status = s);
    if (s.permission) {
      final scope = AppScope.of(context);
      if (await StepsLog.sync(scope.store)) {
        await scope.rewards.refresh();
        if (mounted) setState(() {});
      }
    }
  }

  Future<void> _editGoal() async {
    final store = AppScope.of(context).store;
    var goal = StepsLog.goal(store).toDouble();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Meta de pasos'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${goal.round()} pasos al día', style: Theme.of(ctx).textTheme.titleLarge),
              Slider(
                value: goal,
                min: 3000,
                max: 15000,
                divisions: 24,
                onChanged: (v) => setD(() => goal = v),
              ),
              const Text('Orientativo: cualquier paso extra suma.'),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Guardar')),
          ],
        ),
      ),
    );
    if (ok == true && mounted) {
      await StepsLog.setGoal(store, goal.round());
      if (mounted) {
        await AppScope.of(context).rewards.refresh();
        setState(() {});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _status;
    if (s == null || !s.sensor) return const SizedBox.shrink();
    final t = Theme.of(context).textTheme;
    final store = AppScope.of(context).store;
    final steps = StepsLog.on(store, DateTime.now());
    final goal = StepsLog.goal(store);
    final f = steps.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]}.');
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Card(
        child: ListTile(
          leading: SizedBox(
            width: 46,
            height: 46,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: s.permission ? (steps / goal).clamp(0.0, 1.0) : 0,
                  strokeWidth: 5,
                  backgroundColor: FmColors.line,
                  color: const Color(0xFF3FBF9F),
                ),
                const Text('👟', style: TextStyle(fontSize: 18)),
              ],
            ),
          ),
          title: Text(s.permission ? '$f pasos hoy' : 'Contar mis pasos', style: t.titleSmall),
          subtitle: Text(
            s.permission
                ? (steps >= goal ? '¡Meta de $goal cumplida! 🎉' : 'Meta: $goal · toca para cambiarla')
                : 'Usa el podómetro del teléfono (suma puntos)',
            style: t.bodySmall?.copyWith(color: FmColors.muted),
          ),
          trailing: s.permission
              ? null
              : FilledButton.tonal(
                  onPressed: () async {
                    await StepsLog.requestPermission();
                    await _load();
                  },
                  child: const Text('Activar'),
                ),
          onTap: s.permission ? _editGoal : null,
        ),
      ),
    );
  }
}
