import 'package:flutter/material.dart';

import '../../../app_scope.dart';
import '../../../core/models/habits.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/ids.dart';
import '../../../shared/widgets/common.dart';

/// Agua y hábitos de un día (por defecto hoy).
class HabitsScreen extends StatefulWidget {
  const HabitsScreen({super.key, this.initialTab = 0});
  final int initialTab;

  @override
  State<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends State<HabitsScreen> {
  DateTime _day = dateOnly(DateTime.now());

  bool get _isToday => _day == dateOnly(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final t = Theme.of(context).textTheme;
    return DefaultTabController(
      length: 2,
      initialIndex: widget.initialTab.clamp(0, 1),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Hábitos'),
          bottom: TabBar(
            labelStyle: t.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            tabs: [
              const Tab(text: '💧 Agua'),
              const Tab(text: '✨ Hábitos'),
            ],
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Día anterior',
                    onPressed: () => setState(() => _day = _day.subtract(const Duration(days: 1))),
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  Expanded(
                    child: Text(
                      _isToday ? 'Hoy, ${formatShortDate(_day)}' : formatLongDate(_day),
                      textAlign: TextAlign.center,
                      style: t.titleMedium,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Día siguiente',
                    onPressed: _isToday ? null : () => setState(() => _day = _day.add(const Duration(days: 1))),
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListenableBuilder(
                listenable: scope.habits,
                builder: (context, _) => TabBarView(
                  children: [
                    _WaterTab(day: _day),
                    _HabitsTab(day: _day),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- AGUA

class _WaterTab extends StatelessWidget {
  const _WaterTab({required this.day});
  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final h = AppScope.of(context).habits;
    final t = Theme.of(context).textTheme;
    final s = h.settings;
    final n = h.glasses(day);
    final goal = s.waterGoalGlasses;
    final last7 = [for (var i = 6; i >= 0; i--) day.subtract(Duration(days: i))];

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        Center(
          child: SizedBox(
            width: 220,
            height: 220,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: (n / goal).clamp(0.0, 1.0),
                    strokeWidth: 14,
                    strokeCap: StrokeCap.round,
                    backgroundColor: FmColors.line,
                    color: const Color(0xFF4FB3D9),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('💧', style: TextStyle(fontSize: 34)),
                    Text('$n / $goal', style: t.displaySmall?.copyWith(fontWeight: FontWeight.w800)),
                    Text('vasos · ${(n * s.glassMl / 1000).toStringAsFixed(n * s.glassMl % 1000 == 0 ? 0 : 2)} L',
                        style: t.bodyMedium?.copyWith(color: FmColors.muted)),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (n >= goal)
          Text('¡Meta de agua cumplida! +5 puntos 💜', textAlign: TextAlign.center, style: t.titleSmall)
        else
          Text('Te faltan ${goal - n} ${goal - n == 1 ? 'vaso' : 'vasos'}',
              textAlign: TextAlign.center, style: t.titleSmall?.copyWith(color: FmColors.muted)),
        const SizedBox(height: 18),
        Row(
          children: [
            OutlinedButton(
              onPressed: n == 0 ? null : () => h.addGlass(day, -1),
              child: const Icon(Icons.remove_rounded),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: () => h.addGlass(day),
                icon: const Icon(Icons.local_drink_rounded),
                label: Text('+1 VASO (${s.glassMl} ml)'),
              ),
            ),
          ],
        ),
        const SectionTitle('Últimos 7 días'),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
            child: SizedBox(
              height: 130,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final d in last7)
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text('${h.glasses(d)}', style: t.labelSmall),
                          const SizedBox(height: 4),
                          Container(
                            height: 80 * (h.glasses(d) / goal).clamp(0.04, 1.0),
                            margin: const EdgeInsets.symmetric(horizontal: 6),
                            decoration: BoxDecoration(
                              color: h.waterGoalMet(d) ? const Color(0xFF4FB3D9) : const Color(0xFFBFE3F2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            ['L', 'M', 'X', 'J', 'V', 'S', 'D'][d.weekday - 1],
                            style: t.labelSmall?.copyWith(
                              color: d == day ? FmColors.primary : FmColors.muted,
                              fontWeight: d == day ? FontWeight.w900 : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          s.waterReminders
              ? 'Recordatorios de ${s.reminderStartHour}:00 a ${s.reminderEndHour}:00 cada ${s.reminderEveryHours} h. Puedes cambiarlos en Perfil.'
              : 'Los recordatorios de agua están desactivados (Perfil).',
          style: t.bodySmall?.copyWith(color: FmColors.muted),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _HabitsTab extends StatelessWidget {
  const _HabitsTab({required this.day});
  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final h = AppScope.of(context).habits;
    final t = Theme.of(context).textTheme;
    final list = h.activeHabits;
    final done = list.where((x) => h.isDone(x.id, day)).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text('$done / ${list.length}', style: t.headlineSmall),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    list.isNotEmpty && done == list.length ? '¡Todos hechos! +5 puntos 💜' : 'hábitos completados',
                    style: t.bodyMedium?.copyWith(color: FmColors.muted),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        for (final x in list)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Card(
              color: h.isDone(x.id, day) ? FmColors.lavender : null,
              child: CheckboxListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                value: h.isDone(x.id, day),
                onChanged: (_) => h.toggleHabit(x.id, day),
                secondary: Text(x.emoji, style: const TextStyle(fontSize: 24)),
                title: Text(x.name),
              ),
            ),
          ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const _ManageHabitsScreen())),
          icon: const Icon(Icons.tune_rounded),
          label: const Text('Editar mis hábitos'),
        ),
      ],
    );
  }
}

class _ManageHabitsScreen extends StatelessWidget {
  const _ManageHabitsScreen();

  @override
  Widget build(BuildContext context) {
    final h = AppScope.of(context).habits;
    return ListenableBuilder(
      listenable: h,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: const Text('Mis hábitos')),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _edit(context, null),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Nuevo hábito'),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
          children: [
            for (final x in h.habits)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Card(
                  child: ListTile(
                    leading: Text(x.emoji, style: const TextStyle(fontSize: 24)),
                    title: Text(x.name),
                    subtitle: Text(x.active ? 'Activo' : 'En pausa'),
                    onTap: () => _edit(context, x),
                    trailing: Switch(value: x.active, onChanged: (v) => h.saveHabit(x.copyWith(active: v))),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _edit(BuildContext context, HabitDef? existing) async {
    final h = AppScope.of(context).habits;
    final name = TextEditingController(text: existing?.name);
    final emoji = TextEditingController(text: existing?.emoji ?? '✨');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Nuevo hábito' : 'Editar hábito'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Hábito (ej. Leer 10 minutos)'),
            ),
            const SizedBox(height: 10),
            TextField(controller: emoji, maxLength: 4, decoration: const InputDecoration(labelText: 'Emoji')),
          ],
        ),
        actions: [
          if (existing != null)
            TextButton(onPressed: () => Navigator.pop(ctx, 'delete'), child: const Text('Eliminar')),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, 'save'), child: const Text('Guardar')),
        ],
      ),
    );
    if (result == 'delete' && existing != null) {
      await h.removeHabit(existing.id);
    } else if (result == 'save' && name.text.trim().isNotEmpty) {
      await h.saveHabit(HabitDef(
        id: existing?.id ?? newId('habit'),
        name: name.text.trim(),
        emoji: emoji.text.trim().isEmpty ? '✨' : emoji.text.trim(),
        active: existing?.active ?? true,
      ));
    }
  }
}
