import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../core/models/settings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../shared/widgets/common.dart';
import '../../core/models/habits.dart';
import '../backup/backup_service.dart';
import '../cycle/cycle_screen.dart';
import '../evolution/ui/bmi_card.dart';
import '../library/ui/library_screen.dart';
import '../plans/ui/plan_screen.dart';
import '../workout/ui/summary_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([scope.settings, scope.history, scope.body]),
      builder: (context, _) {
        final s = scope.settings.settings;
        final t = Theme.of(context).textTheme;
        Future<void> set(AppSettings v) => scope.settings.update(v);
        final history = scope.history.sessions;

        return Scaffold(
          appBar: AppBar(title: const Text('Mi perfil')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
            children: [
              Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: FmColors.primary,
                    foregroundColor: Colors.white,
                    child: Text(s.userName.isEmpty ? '?' : s.userName.substring(0, 1).toUpperCase()),
                  ),
                  title: Text(s.userName, style: t.titleMedium),
                  subtitle: const Text('Toca para cambiar tu nombre'),
                  trailing: const Icon(Icons.edit_rounded),
                  onTap: () => _editName(context, s),
                ),
              ),
              const SizedBox(height: 10),
              Card(
                child: ListTile(
                  leading: Icon(Icons.height_rounded, color: FmColors.primary),
                  title: Text(scope.body.heightCm == null ? 'Añade tu estatura' : 'Estatura: ${scope.body.heightCm!.round()} cm'),
                  subtitle: const Text('Se usa para calcular tu IMC'),
                  trailing: const Icon(Icons.edit_rounded),
                  onTap: () => editHeight(context),
                ),
              ),
              const SizedBox(height: 10),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: Icon(Icons.wc_rounded, color: FmColors.primary),
                      title: const Text('Sexo'),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: SegmentedButton<String>(
                          showSelectedIcon: false,
                          segments: const [
                            ButtonSegment(value: 'mujer', label: Text('Mujer')),
                            ButtonSegment(value: 'hombre', label: Text('Hombre')),
                            ButtonSegment(value: 'no_decir', label: Text('No decir')),
                          ],
                          selected: {s.sex},
                          // Al elegir "Mujer" la primera vez se activa el ciclo (se puede apagar).
                          onSelectionChanged: (v) => set(s.copyWith(
                            sex: v.first,
                            cycleEnabled: v.first == 'mujer' && s.sex != 'mujer' ? true : null,
                          )),
                        ),
                      ),
                    ),
                    if (s.canTrackCycle) ...[
                      SwitchListTile(
                        secondary: const Text('🌸', style: TextStyle(fontSize: 22)),
                        title: const Text('Seguimiento del ciclo'),
                        subtitle: const Text('Regla, fases, síntomas y cómo entrenar en cada fase'),
                        value: s.cycleEnabled,
                        onChanged: (v) => set(s.copyWith(cycleEnabled: v)),
                      ),
                      if (s.cycleEnabled)
                        ListTile(
                          leading: const SizedBox(width: 24),
                          title: const Text('Abrir Mi ciclo'),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CycleScreen())),
                        ),
                    ],
                  ],
                ),
              ),
              const SectionTitle('Mi rutina'),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: Icon(Icons.edit_calendar_rounded, color: FmColors.primary),
                      title: const Text('Editar rutina semanal'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PlanScreen())),
                    ),
                    const Divider(indent: 16, endIndent: 16),
                    ListTile(
                      leading: Icon(Icons.menu_book_rounded, color: FmColors.primary),
                      title: const Text('Biblioteca de ejercicios'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LibraryScreen())),
                    ),
                  ],
                ),
              ),
              const SectionTitle('Entrenamiento'),
              Card(
                child: Column(
                  children: [
                    _NumberRow(
                      icon: Icons.timer_outlined,
                      title: 'Descanso por defecto',
                      value: formatClock(Duration(seconds: s.defaultRestSeconds)),
                      onMinus: s.defaultRestSeconds > 15
                          ? () => set(s.copyWith(defaultRestSeconds: s.defaultRestSeconds - 15))
                          : null,
                      onPlus: () => set(s.copyWith(defaultRestSeconds: s.defaultRestSeconds + 15)),
                    ),
                    const Divider(indent: 16, endIndent: 16),
                    _NumberRow(
                      icon: Icons.more_time_rounded,
                      title: 'Botones +/− del descanso',
                      value: '${s.restAdjustStepSeconds} s',
                      onMinus: s.restAdjustStepSeconds > 5
                          ? () => set(s.copyWith(restAdjustStepSeconds: s.restAdjustStepSeconds - 5))
                          : null,
                      onPlus: () => set(s.copyWith(restAdjustStepSeconds: s.restAdjustStepSeconds + 5)),
                    ),
                    const Divider(indent: 16, endIndent: 16),
                    _NumberRow(
                      icon: Icons.water_drop_outlined,
                      title: 'Agua durante el entrenamiento',
                      value: s.hydrationReminderMinutes == 0 ? 'No' : 'cada ${s.hydrationReminderMinutes} min',
                      onMinus: s.hydrationReminderMinutes > 0
                          ? () => set(s.copyWith(hydrationReminderMinutes: s.hydrationReminderMinutes - 5))
                          : null,
                      onPlus: () => set(s.copyWith(hydrationReminderMinutes: s.hydrationReminderMinutes + 5)),
                    ),
                    const Divider(indent: 16, endIndent: 16),
                    ListTile(
                      leading: Icon(Icons.dark_mode_outlined, color: FmColors.primary),
                      title: const Text('Tema'),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: SegmentedButton<String>(
                          showSelectedIcon: false,
                          segments: const [
                            ButtonSegment(value: 'sistema', label: Text('Sistema')),
                            ButtonSegment(value: 'claro', label: Text('Claro')),
                            ButtonSegment(value: 'oscuro', label: Text('Oscuro')),
                          ],
                          selected: {s.themeMode},
                          onSelectionChanged: (v) => set(s.copyWith(themeMode: v.first)),
                        ),
                      ),
                    ),
                    SwitchListTile(
                      secondary: Icon(Icons.record_voice_over_outlined, color: FmColors.primary),
                      title: const Text('Avisos por voz'),
                      subtitle: const Text('Te dice el ejercicio, la última serie y el fin del descanso'),
                      value: s.voiceEnabled,
                      onChanged: (v) => set(s.copyWith(voiceEnabled: v)),
                    ),
                    const Divider(indent: 16, endIndent: 16),
                    SwitchListTile(
                      secondary: Icon(Icons.directions_run_rounded, color: FmColors.primary),
                      title: const Text('Calentamiento antes de entrenar'),
                      subtitle: const Text('~5 min guiados, según lo que entrenas ese día'),
                      value: s.warmupEnabled,
                      onChanged: (v) => set(s.copyWith(warmupEnabled: v)),
                    ),
                    SwitchListTile(
                      secondary: Icon(Icons.self_improvement_rounded, color: FmColors.primary),
                      title: const Text('Estiramientos al terminar'),
                      subtitle: const Text('~5 min de vuelta a la calma'),
                      value: s.cooldownEnabled,
                      onChanged: (v) => set(s.copyWith(cooldownEnabled: v)),
                    ),
                    const Divider(indent: 16, endIndent: 16),
                    SwitchListTile(
                      secondary: Icon(Icons.volume_up_outlined, color: FmColors.primary),
                      title: const Text('Sonidos del descanso'),
                      subtitle: const Text('Tic en 3, 2, 1 y aviso al terminar. Nunca durante el ejercicio.'),
                      value: s.soundEnabled,
                      onChanged: (v) => set(s.copyWith(soundEnabled: v)),
                    ),
                    SwitchListTile(
                      secondary: Icon(Icons.vibration_rounded, color: FmColors.primary),
                      title: const Text('Vibración'),
                      value: s.vibrationEnabled,
                      onChanged: (v) => set(s.copyWith(vibrationEnabled: v)),
                    ),
                  ],
                ),
              ),
              const SectionTitle('Agua, comidas y hábitos'),
              const _HabitsSettingsCard(),
              const SectionTitle('Mi evolución'),
              Card(
                child: _NumberRow(
                  icon: Icons.event_repeat_rounded,
                  title: 'Evaluación corporal',
                  value: 'cada ${scope.body.evaluationEveryDays} días',
                  onMinus: scope.body.evaluationEveryDays > 7
                      ? () => scope.body.setEvaluationEveryDays(scope.body.evaluationEveryDays - 1)
                      : null,
                  onPlus: () => scope.body.setEvaluationEveryDays(scope.body.evaluationEveryDays + 1),
                ),
              ),
              const SectionTitle('Copia de seguridad'),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: Icon(Icons.cloud_upload_outlined, color: FmColors.primary),
                      title: const Text('Exportar mis datos'),
                      subtitle: const Text('Crea un archivo con todo (incluidas las fotos) para guardarlo en Drive, WhatsApp…'),
                      onTap: () => _export(context),
                    ),
                    const Divider(indent: 16, endIndent: 16),
                    ListTile(
                      leading: Icon(Icons.restore_rounded, color: FmColors.primary),
                      title: const Text('Importar una copia'),
                      subtitle: const Text('Para pasar tus datos a un teléfono nuevo'),
                      onTap: () => _import(context),
                    ),
                  ],
                ),
              ),
              SectionTitle('Historial (${history.length})'),
              if (history.isEmpty)
                const EmptyHint(
                  icon: Icons.history_rounded,
                  title: 'Aún no hay entrenamientos',
                  text: 'Cuando termines uno aparecerá aquí.',
                )
              else
                Card(
                  child: Column(
                    children: [
                      for (final (i, h) in history.take(30).indexed) ...[
                        if (i > 0) const Divider(indent: 16, endIndent: 16),
                        ListTile(
                          title: Text(h.dayTitle),
                          subtitle: Text(
                            '${formatShortDate(h.startedAt)} · ${formatDurationShort(h.activeDuration(h.finishedAt ?? h.startedAt))} · '
                            '${h.completedSets}/${h.plannedSets} series',
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => SummaryScreen(sessionId: h.id)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _export(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(const SnackBar(content: Text('Preparando la copia…')));
    try {
      await BackupService(AppScope.of(context)).exportAndShare();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('No se pudo exportar: $e')));
    }
  }

  Future<void> _import(BuildContext context) async {
    final scope = AppScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final service = BackupService(scope);
    final BackupPreview? b;
    try {
      b = await service.pickBackup();
    } on FormatException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
      return;
    }
    if (b == null || !context.mounted) return;
    final backup = b;
    final when = backup.createdAt;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Restaurar esta copia?'),
        content: Text(
          '${when == null ? '' : 'Copia del ${formatLongDate(when)}.\n'}'
          '${backup.workouts} entrenamientos, ${backup.records} registros, ${backup.photos} fotos.\n\n'
          'Se reemplazarán TODOS los datos actuales de este teléfono.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Restaurar')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await service.restore(backup);
      messenger.showSnackBar(const SnackBar(content: Text('¡Datos restaurados!')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('No se pudo restaurar: $e')));
    }
  }

  Future<void> _editName(BuildContext context, AppSettings s) async {
    final ctrl = TextEditingController(text: s.userName);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Cómo te llamas?'),
        content: TextField(controller: ctrl, autofocus: true, textCapitalization: TextCapitalization.words),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Guardar')),
        ],
      ),
    );
    if (name == null || name.isEmpty || !context.mounted) return;
    await AppScope.of(context).settings.update(s.copyWith(userName: name));
  }
}

class _NumberRow extends StatelessWidget {
  const _NumberRow({required this.icon, required this.title, required this.value, this.onMinus, this.onPlus});
  final IconData icon;
  final String title;
  final String value;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;

  @override
  Widget build(BuildContext context) => ListTile(
        leading: Icon(icon, color: FmColors.primary),
        title: Text(title),
        subtitle: Text(value),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(onPressed: onMinus, icon: const Icon(Icons.remove_circle_outline_rounded)),
            IconButton(onPressed: onPlus, icon: const Icon(Icons.add_circle_outline_rounded)),
          ],
        ),
      );
}

class _HabitsSettingsCard extends StatelessWidget {
  const _HabitsSettingsCard();

  @override
  Widget build(BuildContext context) {
    final h = AppScope.of(context).habits;
    return ListenableBuilder(
      listenable: h,
      builder: (context, _) {
        final s = h.settings;
        Future<void> set(HabitsSettings v) => h.updateSettings(v);
        const divider = Divider(indent: 16, endIndent: 16);
        return Card(
          child: Column(
            children: [
              _NumberRow(
                icon: Icons.local_drink_outlined,
                title: 'Meta de agua',
                value: '${s.waterGoalGlasses} vasos de ${s.glassMl} ml',
                onMinus: s.waterGoalGlasses > 1 ? () => set(s.copyWith(waterGoalGlasses: s.waterGoalGlasses - 1)) : null,
                onPlus: s.waterGoalGlasses < 20 ? () => set(s.copyWith(waterGoalGlasses: s.waterGoalGlasses + 1)) : null,
              ),
              divider,
              _NumberRow(
                icon: Icons.straighten_rounded,
                title: 'Tamaño del vaso',
                value: '${s.glassMl} ml',
                onMinus: s.glassMl > 100 ? () => set(s.copyWith(glassMl: s.glassMl - 50)) : null,
                onPlus: s.glassMl < 1000 ? () => set(s.copyWith(glassMl: s.glassMl + 50)) : null,
              ),
              divider,
              SwitchListTile(
                secondary: Icon(Icons.notifications_active_outlined, color: FmColors.primary),
                title: const Text('Recordatorios de agua'),
                subtitle: Text('De ${s.reminderStartHour}:00 a ${s.reminderEndHour}:00 · se paran al cumplir tu meta'),
                value: s.waterReminders,
                onChanged: (v) => set(s.copyWith(waterReminders: v)),
              ),
              if (s.waterReminders) ...[
                _NumberRow(
                  icon: Icons.wb_twilight_rounded,
                  title: 'Desde',
                  value: '${s.reminderStartHour}:00',
                  onMinus: s.reminderStartHour > 5 ? () => set(s.copyWith(reminderStartHour: s.reminderStartHour - 1)) : null,
                  onPlus: s.reminderStartHour < s.reminderEndHour - 1
                      ? () => set(s.copyWith(reminderStartHour: s.reminderStartHour + 1))
                      : null,
                ),
                _NumberRow(
                  icon: Icons.nights_stay_outlined,
                  title: 'Hasta',
                  value: '${s.reminderEndHour}:00',
                  onMinus: s.reminderEndHour > s.reminderStartHour + 1
                      ? () => set(s.copyWith(reminderEndHour: s.reminderEndHour - 1))
                      : null,
                  onPlus: s.reminderEndHour < 23 ? () => set(s.copyWith(reminderEndHour: s.reminderEndHour + 1)) : null,
                ),
                _NumberRow(
                  icon: Icons.av_timer_rounded,
                  title: 'Cada',
                  value: '${s.reminderEveryHours} h',
                  onMinus: s.reminderEveryHours > 1 ? () => set(s.copyWith(reminderEveryHours: s.reminderEveryHours - 1)) : null,
                  onPlus: s.reminderEveryHours < 6 ? () => set(s.copyWith(reminderEveryHours: s.reminderEveryHours + 1)) : null,
                ),
              ],
              divider,
              SwitchListTile(
                secondary: Icon(Icons.restaurant_outlined, color: FmColors.primary),
                title: const Text('Registro de comidas'),
                subtitle: const Text('Proteínas y calorías aproximadas (opcional)'),
                value: s.nutritionEnabled,
                onChanged: (v) => set(s.copyWith(nutritionEnabled: v)),
              ),
              if (s.nutritionEnabled) ...[
                _NumberRow(
                  icon: Icons.egg_alt_outlined,
                  title: 'Proteína orientativa',
                  value: '${s.proteinTarget} g/día',
                  onMinus: s.proteinTarget > 40 ? () => set(s.copyWith(proteinTarget: s.proteinTarget - 5)) : null,
                  onPlus: s.proteinTarget < 250 ? () => set(s.copyWith(proteinTarget: s.proteinTarget + 5)) : null,
                ),
                _NumberRow(
                  icon: Icons.local_fire_department_outlined,
                  title: 'Calorías orientativas',
                  value: '${s.kcalTarget} kcal/día',
                  onMinus: s.kcalTarget > 1200 ? () => set(s.copyWith(kcalTarget: s.kcalTarget - 50)) : null,
                  onPlus: s.kcalTarget < 4000 ? () => set(s.copyWith(kcalTarget: s.kcalTarget + 50)) : null,
                ),
              ],
              divider,
              SwitchListTile(
                secondary: Icon(Icons.fitness_center_rounded, color: FmColors.primary),
                title: const Text('Aviso "Es hora de entrenar"'),
                subtitle: const Text('Solo los días con entreno y si aún no has entrenado'),
                value: s.workoutReminder,
                onChanged: (v) => set(s.copyWith(workoutReminder: v)),
              ),
              if (s.workoutReminder)
                _NumberRow(
                  icon: Icons.alarm_rounded,
                  title: 'Hora del aviso',
                  value: '${s.workoutReminderHour}:${s.workoutReminderMinute.toString().padLeft(2, '0')}',
                  onMinus: s.workoutReminderHour * 60 + s.workoutReminderMinute > 5 * 60
                      ? () {
                          final m = s.workoutReminderHour * 60 + s.workoutReminderMinute - 30;
                          set(s.copyWith(workoutReminderHour: m ~/ 60, workoutReminderMinute: m % 60));
                        }
                      : null,
                  onPlus: s.workoutReminderHour * 60 + s.workoutReminderMinute < 22 * 60
                      ? () {
                          final m = s.workoutReminderHour * 60 + s.workoutReminderMinute + 30;
                          set(s.copyWith(workoutReminderHour: m ~/ 60, workoutReminderMinute: m % 60));
                        }
                      : null,
                ),
              divider,
              SwitchListTile(
                secondary: Icon(Icons.event_available_outlined, color: FmColors.primary),
                title: const Text('Aviso de evaluación corporal'),
                subtitle: const Text('Notificación a las 10:00 el día que toca'),
                value: s.evaluationReminder,
                onChanged: (v) => set(s.copyWith(evaluationReminder: v)),
              ),
            ],
          ),
        );
      },
    );
  }
}
