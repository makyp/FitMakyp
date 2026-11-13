import 'package:flutter/material.dart';

import '../../../app_scope.dart';
import '../../../core/models/habits.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/ids.dart';
import '../../../shared/widgets/common.dart';
import '../domain/hand_portions.dart';
import '../../../shared/widgets/progress_photo.dart';
import 'meal_photo_diary.dart';
import 'meal_sheet.dart';

/// Agua, comidas y hábitos de un día (por defecto hoy).
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
    final nutrition = scope.habits.settings.nutritionEnabled;
    return DefaultTabController(
      length: nutrition ? 3 : 2,
      initialIndex: widget.initialTab.clamp(0, nutrition ? 2 : 1),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Hábitos'),
          bottom: TabBar(
            labelStyle: t.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            tabs: [
              const Tab(text: '💧 Agua'),
              if (nutrition) const Tab(text: '🍽️ Comidas'),
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
                    if (nutrition) _MealsTab(day: _day),
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

// ---------------------------------------------------------------- COMIDAS

class _MealsTab extends StatelessWidget {
  const _MealsTab({required this.day});
  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final h = AppScope.of(context).habits;
    final t = Theme.of(context).textTheme;
    final s = h.settings;
    final meals = h.mealsOn(day);
    final kcal = h.kcalOn(day);
    final protein = h.proteinOn(day);
    final portions = h.portionsOn(day);

    Widget bar(String label, int value, int target, String unit) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(label, style: t.titleSmall),
                const Spacer(),
                Text('$value / $target $unit', style: t.labelLarge?.copyWith(color: FmColors.primary)),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: target == 0 ? 0 : (value / target).clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: FmColors.line,
              ),
            ),
          ],
        );

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'meal',
        onPressed: () => showMealSheet(context, day: day),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Añadir comida'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  bar('Proteína', protein, s.proteinTarget, 'g'),
                  const SizedBox(height: 14),
                  bar('Calorías aprox.', kcal, s.kcalTarget, 'kcal'),
                  if (!portions.isEmpty) ...[
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        for (final p in HandPortion.values)
                          Column(
                            children: [
                              Text(p.emoji, style: const TextStyle(fontSize: 22)),
                              Text(HandPortions.amount(portions[p]), style: t.titleMedium?.copyWith(color: FmColors.primary)),
                              Text(p.label, style: t.labelSmall?.copyWith(color: FmColors.muted)),
                            ],
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MealPhotoDiary())),
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Diario de fotos'),
            ),
          ),
          Text(
            'Objetivos orientativos y configurables en Perfil. No son una pauta médica: escucha a tu cuerpo.',
            style: t.bodySmall?.copyWith(color: FmColors.muted),
          ),
          if (meals.isEmpty) ...[
            const SizedBox(height: 14),
            const HandGuideCard(),
          ],
          for (final type in MealType.values)
            if (meals.any((m) => m.type == type)) ...[
              SectionTitle('${type.emoji}  ${type.label}'),
              for (final m in meals.where((m) => m.type == type))
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Card(
                    child: ListTile(
                      leading: m.photoId == null
                          ? null
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: SizedBox(width: 52, height: 52, child: ProgressPhoto(photoId: m.photoId!)),
                            ),
                      title: Text(m.description),
                      subtitle: Text([
                        '${m.at.hour.toString().padLeft(2, '0')}:${m.at.minute.toString().padLeft(2, '0')}',
                        if (m.portions != null) m.portions!.short,
                        if (m.kcal != null) '${m.portions != null ? '≈' : ''}${m.kcal} kcal',
                        if (m.protein != null) '${m.portions != null ? '≈' : ''}${m.protein} g proteína',
                      ].join(' · ')),
                      trailing: const Icon(Icons.edit_outlined, size: 20),
                      onTap: () => showMealSheet(context, day: day, existing: m),
                    ),
                  ),
                ),
            ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- HÁBITOS

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


/// Explica el método de la mano para quien no pesa la comida.
class HandGuideCard extends StatelessWidget {
  const HandGuideCard({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Card(
      color: FmColors.lavender,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('¿No pesas tu comida? ¡Perfecto! 🙌', style: t.titleMedium?.copyWith(color: FmColors.ink)),
            const SizedBox(height: 4),
            Text(
              'Usa tu mano como medida: siempre la llevas contigo y es proporcional a tu cuerpo.',
              style: t.bodyMedium?.copyWith(color: FmColors.ink),
            ),
            const SizedBox(height: 12),
            for (final p in HandPortion.values)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Text(p.emoji, style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text.rich(
                        TextSpan(children: [
                          TextSpan(text: '1 ${p.unit} = ', style: const TextStyle(fontWeight: FontWeight.w800)),
                          TextSpan(text: p.label.toLowerCase()),
                        ]),
                        style: t.bodyMedium?.copyWith(color: FmColors.ink),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 4),
            Text(
              'Toca "Añadir comida" y cuenta las porciones de tu plato. La app calcula una idea aproximada de proteína y calorías.',
              style: t.bodySmall?.copyWith(color: FmColors.ink),
            ),
          ],
        ),
      ),
    );
  }
}
