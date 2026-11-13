import '../../core/utils/gender.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_scope.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/pet_avatar.dart';
import '../goals/domain/rewards.dart';
import '../goals/ui/achievements_screen.dart';
import '../goals/ui/goals_screen.dart';
import 'domain/pet_items.dart';

/// Mi mascota: nivel, puntos, tienda de ropa/accesorios y cómo ganar puntos.
class PetScreen extends StatefulWidget {
  const PetScreen({super.key});

  @override
  State<PetScreen> createState() => _PetScreenState();
}

class _PetScreenState extends State<PetScreen> {
  PetSlot _slot = PetSlot.head;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([scope.rewards, scope.pet]),
      builder: (context, _) {
        final t = Theme.of(context).textTheme;
        final r = scope.rewards;
        final pet = scope.pet;
        final trainedToday = scope.history.trainedDates.contains(dateOnly(DateTime.now()));
        final isTrainingDay = scope.plans.today?.isTraining ?? false;
        final mood = trainedToday
            ? PetMood.celebrating
            : isTrainingDay
                ? PetMood.motivating
                : PetMood.resting;
        final items = petItems.where((i) => i.slot == _slot).toList();

        return Scaffold(
          appBar: AppBar(title: const Text('Mi mascota')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            children: [
              _PetStage(mood: mood, look: pet.look),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(pet.name, style: t.headlineMedium),
                  IconButton(
                    tooltip: 'Cambiar nombre',
                    icon: const Icon(Icons.edit_rounded, size: 20),
                    onPressed: () => _rename(context),
                  ),
                ],
              ),
              Text(
                trainedToday
                    ? '¡Hoy has entrenado! Estoy celebrando contigo.'
                    : isTrainingDay
                        ? 'Te espero para entrenar hoy.'
                        : 'Hoy descansamos. Recuperarse también suma.',
                style: t.bodyLarge?.copyWith(color: FmColors.muted),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(color: FmColors.primary, borderRadius: BorderRadius.circular(12)),
                            child: Text('Nivel ${r.level}',
                                style: t.labelLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                          ),
                          const Spacer(),
                          const Icon(Icons.stars_rounded, color: Color(0xFFD69E2E)),
                          const SizedBox(width: 4),
                          Text('${r.balance} puntos', style: t.titleMedium),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: r.levelProgressValue,
                          minHeight: 8,
                          backgroundColor: FmColors.line,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text('${r.xp} / ${r.nextLevelAt} de experiencia para el nivel ${r.level + 1}',
                            style: t.bodySmall?.copyWith(color: FmColors.muted)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Text('🏅', style: TextStyle(fontSize: 26)),
                  title: const Text('Mis insignias'),
                  subtitle: Text(
                      '${r.achievementStatus.where((a) => a.unlocked).length} de ${r.achievementStatus.length} conseguidas'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AchievementsScreen())),
                ),
              ),
              const SectionTitle('Tienda y armario'),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final s in PetSlot.values)
                    ChoiceChip(
                      label: Text(s.label),
                      selected: _slot == s,
                      onSelected: (_) => setState(() => _slot = s),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 0.78,
                children: [for (final i in items) _ItemTile(item: i, level: r.level, balance: r.balance)],
              ),
              SectionTitle('Cómo ganar puntos',
                  trailing: TextButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GoalsScreen())),
                    child: const Text('Mis metas'),
                  )),
              Card(
                child: Column(
                  children: [
                    _rule('Terminar un entrenamiento', '+${PointRules.workout}'),
                    _rule('Completarlo entero', '+${PointRules.fullWorkoutBonus} extra'),
                    _rule('Registrar peso o medidas (1 por semana)', '+${PointRules.progressRecord}'),
                    _rule('Registro diario de cómo te sientes', '+${PointRules.checkin}'),
                    _rule('Cumplir una meta', '+${PointRules.goal}'),
                    _rule('Cumplir tu meta de agua del día', '+${PointRules.waterDay}'),
                    _rule('Completar todos tus hábitos del día', '+${PointRules.habitsDay}'),
                    _rule('Llegar a tu meta de pasos', '+${PointRules.stepsDay}'),
                    _rule('Hacer la rutina matutina', '+${PointRules.morning}'),
                    _rule('Cumplir un reto semanal', '+${PointRules.challenge}'),
                    _rule('Semana con los 3 retos', '🏆 premio'),
                    _rule('Rachas de 3, 7, 14, 30 y 60 días', '+30 … +600'),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text('Descansar nunca te quita puntos ni niveles.',
                  style: t.bodySmall?.copyWith(color: FmColors.muted), textAlign: TextAlign.center),
            ],
          ),
        );
      },
    );
  }

  Widget _rule(String text, String pts) => ListTile(
        dense: true,
        title: Text(text),
        trailing: Text(pts, style: TextStyle(fontWeight: FontWeight.w800, color: FmColors.primary)),
      );

  Future<void> _rename(BuildContext context) async {
    final pet = AppScope.of(context).pet;
    final ctrl = TextEditingController(text: pet.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nombre de tu mascota'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 16,
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Guardar')),
        ],
      ),
    );
    if (name != null) await pet.rename(name);
  }
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({required this.item, required this.level, required this.balance});
  final PetItem item;
  final int level;
  final int balance;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final pet = AppScope.of(context).pet;
    final owned = pet.owns(item.id);
    final equipped = pet.equippedIn(item.slot) == item.id ||
        (item.slot == PetSlot.color && pet.equippedIn(PetSlot.color) == null && item.id == defaultColorId);
    final locked = !owned && (item.prize || level < item.minLevel);
    final previewLook = _previewLook(pet.look);

    return Material(
      color: equipped ? FmColors.lavender : FmColors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => owned ? pet.toggleEquip(item) : _buy(context, previewLook),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: equipped ? FmColors.primary : FmColors.line, width: equipped ? 2 : 1),
          ),
          padding: const EdgeInsets.all(6),
          child: Column(
            children: [
              Expanded(
                child: Opacity(
                  opacity: locked ? 0.4 : 1,
                  child: PetAvatar(size: 76, look: previewLook),
                ),
              ),
              Text(context.g(item.name), style: t.labelMedium, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              if (equipped)
                Text('Puesto', style: t.labelSmall?.copyWith(color: FmColors.primary, fontWeight: FontWeight.w800))
              else if (owned)
                Text('Tuyo', style: t.labelSmall?.copyWith(color: FmColors.muted))
              else if (item.prize)
                Text('🏆 Premio', style: t.labelSmall?.copyWith(color: FmColors.muted))
              else if (locked)
                Text('🔒 Nivel ${item.minLevel}', style: t.labelSmall?.copyWith(color: FmColors.muted))
              else
                Text('⭐ ${item.price}', style: t.labelSmall?.copyWith(fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ),
    );
  }

  /// Cómo se vería la mascota con este objeto puesto.
  PetLook _previewLook(PetLook cur) => cur.wearing(item.slot, item.id);

  Future<void> _buy(BuildContext context, PetLook preview) async {
    final scope = AppScope.of(context);
    if (item.prize) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(context.g(item.name)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PetAvatar(size: 140, look: preview, mood: PetMood.celebrating),
              const SizedBox(height: 8),
              const Text(
                'Es un premio: se gana completando los 3 retos de una semana. Cada semana perfecta desbloquea uno nuevo.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('¡A por ello!'))],
        ),
      );
      return;
    }
    final can = level >= item.minLevel && balance >= item.price;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.g(item.name)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PetAvatar(size: 140, look: preview, mood: PetMood.celebrating),
            const SizedBox(height: 8),
            Text(
              level < item.minLevel
                  ? 'Se desbloquea en el nivel ${item.minLevel}. ¡Sigue entrenando!'
                  : balance < item.price
                      ? 'Cuesta ${item.price} puntos. Te faltan ${item.price - balance}.'
                      : 'Cuesta ${item.price} puntos. Tienes $balance.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cerrar')),
          if (can) FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Comprar')),
        ],
      ),
    );
    if (ok != true) return;
    final err = await scope.pet.buy(item, balance: balance, level: level);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err ?? '¡${context.g(item.name)} es tuyo! Ya lo lleva puesto.')));
    }
  }
}


/// La mascota con acciones: tócala o elige qué quieres que haga.
class _PetStage extends StatefulWidget {
  const _PetStage({required this.mood, required this.look});
  final PetMood mood;
  final PetLook look;

  @override
  State<_PetStage> createState() => _PetStageState();
}

class _PetStageState extends State<_PetStage> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this)
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) setState(() => _action = null);
    });
  PetAction? _action;
  String? _bubble;
  final _rnd = math.Random();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _do(PetAction a) {
    HapticFeedback.lightImpact();
    setState(() {
      _action = a;
      _bubble = a.phrase;
    });
    _c.duration = Duration(milliseconds: a == PetAction.siesta ? 3600 : 2400);
    _c.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      children: [
        SizedBox(
          height: 66,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: _bubble == null
                ? Center(
                    key: const ValueKey('hint'),
                    child: Text('Tócame o elige qué hago 👇', style: t.bodySmall?.copyWith(color: FmColors.muted)),
                  )
                : Container(
                    key: ValueKey(_bubble),
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: FmColors.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: FmColors.line),
                      boxShadow: const [BoxShadow(blurRadius: 8, color: Color(0x14000000))],
                    ),
                    child: Text(_bubble!, style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                  ),
          ),
        ),
        GestureDetector(
          onTap: () {
            const fun = [PetAction.mimos, PetAction.mimos, PetAction.bailar, PetAction.voltereta, PetAction.estirar];
            _do(fun[_rnd.nextInt(fun.length)]);
          },
          child: AnimatedBuilder(
            animation: _c,
            builder: (_, _) => PetAvatar(
              size: 190,
              mood: widget.mood,
              look: widget.look,
              action: _action,
              actionT: _c.value,
            ),
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: PetAction.values.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final a = PetAction.values[i];
              return ActionChip(
                avatar: Text(a.emoji),
                label: Text(a.label),
                onPressed: () => _do(a),
              );
            },
          ),
        ),
      ],
    );
  }
}
