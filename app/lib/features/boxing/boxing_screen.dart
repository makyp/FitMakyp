import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../core/models/plan.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/gender.dart';
import '../../shared/widgets/body_figure.dart';
import '../../shared/widgets/exercise_thumb.dart';
import '../library/ui/exercise_detail_screen.dart';
import 'boxing.dart';

/// Boxeo para principiantes: qué incluye, consejos y agregarlo a la semana.
class BoxingScreen extends StatefulWidget {
  const BoxingScreen({super.key});

  @override
  State<BoxingScreen> createState() => _BoxingScreenState();
}

class _BoxingScreenState extends State<BoxingScreen> {
  Set<int>? _days;

  Future<void> _apply() async {
    final plans = AppScope.of(context).plans;
    final days = (_days!.toList()..sort());
    final replaced = [
      for (final w in days)
        if (plans.active.dayForWeekday(w) case final d? when d.isTraining && !isBoxingDay(d)) '${d.weekdayName}: ${d.title}',
    ];
    if (replaced.isNotEmpty) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('¿Cambiar estos días?'),
          content: Text('Estos entrenamientos pasarán a ser de boxeo:\n\n${replaced.join('\n')}\n\nPuedes volver a cambiarlos en Editar rutina.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Cambiar')),
          ],
        ),
      );
      if (ok != true) return;
    }
    for (final (i, w) in days.indexed) {
      final d = plans.active.dayForWeekday(w);
      if (d != null) await plans.updateDay(boxingDay(d, i));
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('🥊 ¡Boxeo agregado ${days.length == 1 ? 'el ${weekdayNames[days.first - 1].toLowerCase()}' : 'en ${days.length} días'}!')),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scope = AppScope.of(context);
    final plan = scope.plans.active;
    // Por defecto se proponen 2 días de descanso (o los que ya son de boxeo).
    _days ??= {
      ...plan.days.where(isBoxingDay).map((d) => d.weekday),
      if (!plan.days.any(isBoxingDay)) ...plan.days.where((d) => !d.isTraining && d.weekday < 7).map((d) => d.weekday).take(2),
    };
    final lib = scope.library;
    final man = context.isMan;

    return Scaffold(
      appBar: AppBar(title: const Text('Boxeo')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(colors: [Color(0xFF2B1B43), Color(0xFF7041B8)]),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 18, 0, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('🥊 PRINCIPIANTE',
                            style: TextStyle(color: Color(0xFFDCCBFA), fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
                        const SizedBox(height: 6),
                        Text('Boxeo con saco y pesas', style: t.titleLarge?.copyWith(color: Colors.white)),
                        const SizedBox(height: 6),
                        Text('Técnica, cardio y fuerza en rondas de 2 minutos.',
                            style: t.bodyMedium?.copyWith(color: Colors.white)),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  width: 140,
                  height: 190,
                  child: FigureMoveAnimation(
                    start: BoxingPoses.guard,
                    end: BoxingPoses.jab,
                    hair: man ? FigureHair.short : FigureHair.ponytail,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          for (final s in boxingSessions) ...[
            Text('${s.title} · ~${boxingMinutes(s)} min', style: t.titleMedium),
            const SizedBox(height: 2),
            Text(s.summary, style: t.bodySmall?.copyWith(color: FmColors.muted)),
            const SizedBox(height: 6),
            Card(
              child: Column(
                children: [
                  for (final (i, (id, sets, target, _)) in s.exercises.indexed)
                    if (lib.byId(id) case final ex?)
                      ListTile(
                        dense: true,
                        leading: ExerciseThumb(src: ex.media.endSrc ?? ex.media.src, number: i + 1),
                        title: Text(ex.name),
                        subtitle: Text(target.isTime && target.min >= 60
                            ? '$sets ${sets == 1 ? 'ronda' : 'rondas'} de ${target.min ~/ 60} min'
                            : '$sets × ${target.label}'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ExerciseDetailScreen(exerciseId: id))),
                      ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],
          Card(
            color: FmColors.dark ? const Color(0xFF3A3020) : const Color(0xFFFFF6DC),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Antes de golpear el saco', style: t.titleSmall),
                  const SizedBox(height: 6),
                  Text(
                    '• Usa siempre vendas y guantes: protegen muñecas y nudillos.\n'
                    '• Técnica antes que fuerza: golpea al 50 % las primeras semanas.\n'
                    '• Muñeca recta y no bloquees el codo al estirar.\n'
                    '• Suelta el aire en cada golpe y no dejes de mirar el saco.\n'
                    '• No golpees con mancuernas en las manos: las pesas, aparte.',
                    style: t.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('¿Qué días quieres boxear?', style: t.titleMedium),
          const SizedBox(height: 4),
          Text('Se alternan las dos sesiones. El calentamiento y los estiramientos se añaden solos.',
              style: t.bodySmall?.copyWith(color: FmColors.muted)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final d in [...plan.days]..sort((a, b) => a.weekday.compareTo(b.weekday)))
                FilterChip(
                  label: Text('${d.weekdayName.substring(0, 3)} · ${isBoxingDay(d) ? '🥊' : d.isTraining ? '💪' : '😴'}'),
                  selected: _days!.contains(d.weekday),
                  onSelected: (on) => setState(() => on
                      ? (_days!.length < 3 ? _days!.add(d.weekday) : null)
                      : _days!.remove(d.weekday)),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text('💪 ya entrenas · 😴 descanso · 🥊 boxeo · máximo 3 días',
              style: t.labelSmall?.copyWith(color: FmColors.muted)),
          const SizedBox(height: 16),
          FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
            onPressed: _days!.isEmpty ? null : _apply,
            icon: const Text('🥊'),
            label: const Text('AGREGAR A MI SEMANA'),
          ),
        ],
      ),
    );
  }
}
