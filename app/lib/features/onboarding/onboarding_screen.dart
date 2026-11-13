import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../core/data/starter_plans.dart';
import '../../core/models/settings.dart';
import '../../core/storage/local_store.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/pet_avatar.dart';
import '../backup/backup_service.dart';

const onboardedKey = 'onboarded';

/// Quien ya usaba la app antes de que existiera la bienvenida no la ve (y conserva su nombre).
Future<void> skipOnboardingForExistingUser(LocalStore store) async {
  if (store.readJson(onboardedKey) != null) return;
  final existing = ['history', 'settings', 'progressRecords', 'checkins', 'plans', 'pet'].any((k) => store.readJson(k) != null);
  if (!existing) return;
  if (store.readJson('settings') == null) {
    await store.writeJson('settings', const AppSettings(userName: 'Makyp').toJson());
  }
  await store.writeJson(onboardedKey, true);
}

/// Bienvenida para personas nuevas: nombre, datos básicos, mascota, rutina y hábitos.
/// Todo se puede cambiar después en Perfil.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onDone});
  final VoidCallback onDone;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _page = PageController();
  int _step = 0;
  static const _steps = 5;

  final _name = TextEditingController();
  final _height = TextEditingController();
  final _petName = TextEditingController(text: 'Lila');
  String _sex = 'no_decir';
  bool _cycle = false;
  int _days = 3;
  StarterPlace _place = StarterPlace.mancuernas;
  StarterLevel _level = StarterLevel.principiante;
  StarterFocus _focus = StarterFocus.equilibrado;
  int _water = 8;
  bool _reminder = true;
  int _reminderHour = 18;
  bool _meals = true;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_name, _height, _petName]) {
      c.dispose();
    }
    _page.dispose();
    super.dispose();
  }

  bool get _canNext => _step != 1 || _name.text.trim().isNotEmpty;

  void _go(int step) {
    FocusScope.of(context).unfocus();
    setState(() => _step = step);
    _page.animateToPage(step, duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);
  }

  Future<void> _finish() async {
    setState(() => _saving = true);
    final s = AppScope.of(context);
    await s.settings.update(s.settings.settings.copyWith(
      userName: _name.text.trim(),
      sex: _sex,
      cycleEnabled: _sex != 'hombre' && _cycle,
    ));
    final h = double.tryParse(_height.text.trim().replaceAll(',', '.'));
    if (h != null && h >= 120 && h <= 230) await s.body.setHeight(h);
    if (_petName.text.trim().isNotEmpty) await s.pet.rename(_petName.text.trim());
    final plan = buildStarterPlan(daysPerWeek: _days, place: _place, level: _level, focus: _focus);
    final seed = s.plans.plans.where((p) => p.id == 'plan_inicial').toList();
    await s.plans.addAndActivate(plan);
    for (final p in seed) {
      await s.plans.delete(p.id);
    }
    await s.habits.updateSettings(s.habits.settings.copyWith(
      waterGoalGlasses: _water,
      workoutReminder: _reminder,
      workoutReminderHour: _reminderHour,
      workoutReminderMinute: 0,
      nutritionEnabled: _meals,
    ));
    await s.store.writeJson(onboardedKey, true);
    widget.onDone();
  }

  Future<void> _restore() async {
    final scope = AppScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final service = BackupService(scope);
    try {
      final b = await service.pickBackup();
      if (b == null) return;
      await scope.store.writeJson(onboardedKey, true);
      await service.restore(b);
    } on FormatException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('No se pudo restaurar: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            if (_step > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Atrás',
                      onPressed: () => _go(_step - 1),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(value: _step / (_steps - 1), minHeight: 6, backgroundColor: FmColors.line),
                      ),
                    ),
                  ],
                ),
              ),
            // Con clave: al aparecer la barra de arriba, el PageView no se recrea (y no vuelve a la página 0).
            Expanded(
              key: const ValueKey('pages'),
              child: PageView(
                controller: _page,
                physics: const NeverScrollableScrollPhysics(),
                children: [_welcome(t), _you(t), _training(t), _habits(t), _privacy(t)],
              ),
            ),
            if (_step > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
                  onPressed: !_canNext || _saving
                      ? null
                      : _step == _steps - 1
                          ? _finish
                          : () => _go(_step + 1),
                  child: Text(_step == _steps - 1 ? '¡EMPEZAR!' : 'SIGUIENTE'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _page0(List<Widget> children) => ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
        children: children,
      );

  Widget _title(TextTheme t, String title, String sub) => Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: t.headlineSmall),
            const SizedBox(height: 6),
            Text(sub, style: t.bodyMedium?.copyWith(color: FmColors.muted)),
          ],
        ),
      );

  Widget _label(TextTheme t, String s) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 8),
        child: Text(s, style: t.titleSmall),
      );

  Widget _choices<T>(List<T> values, T selected, String Function(T) label, ValueChanged<T> onPick) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final v in values)
            ChoiceChip(label: Text(label(v)), selected: v == selected, onSelected: (_) => setState(() => onPick(v))),
        ],
      );

  // 0 · Bienvenida
  Widget _welcome(TextTheme t) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Spacer(),
            const PetAvatar(size: 170, mood: PetMood.celebrating),
            const SizedBox(height: 20),
            Text('¡Hola! Te doy la bienvenida a FitMakyp', style: t.headlineSmall, textAlign: TextAlign.center),
            const SizedBox(height: 10),
            Text(
              'Tu rutina, tu progreso y tus hábitos en un solo lugar, con una mascota que crece contigo. '
              'Configurarla lleva un minuto.',
              style: t.bodyLarge?.copyWith(color: FmColors.muted),
              textAlign: TextAlign.center,
            ),
            const Spacer(),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
              onPressed: () => _go(1),
              child: const Text('EMPEZAR'),
            ),
            const SizedBox(height: 6),
            TextButton(onPressed: _restore, child: const Text('Ya tengo una copia de seguridad')),
          ],
        ),
      );

  // 1 · Tú y tu mascota
  Widget _you(TextTheme t) => _page0([
        _title(t, 'Cuéntame de ti', 'Solo se guarda en tu teléfono.'),
        TextField(
          controller: _name,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: '¿Cómo te llamas?'),
          onChanged: (_) => setState(() {}),
        ),
        _label(t, 'Sexo'),
        _choices(
          const ['mujer', 'hombre', 'no_decir'],
          _sex,
          (v) => switch (v) { 'mujer' => 'Mujer', 'hombre' => 'Hombre', _ => 'Prefiero no decir' },
          (v) {
            _sex = v;
            _cycle = v == 'mujer';
          },
        ),
        if (_sex != 'hombre')
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Seguimiento del ciclo menstrual'),
            subtitle: const Text('Opcional. Puedes cambiarlo cuando quieras.'),
            value: _cycle,
            onChanged: (v) => setState(() => _cycle = v),
          ),
        const SizedBox(height: 8),
        TextField(
          controller: _height,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Estatura (opcional)', suffixText: 'cm', helperText: 'Para calcular tu IMC'),
        ),
        _label(t, 'Tu mascota'),
        Row(
          children: [
            const PetAvatar(size: 64),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _petName,
                maxLength: 16,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Ponle nombre', counterText: ''),
              ),
            ),
          ],
        ),
      ]);

  // 2 · Entreno
  Widget _training(TextTheme t) {
    final plan = buildStarterPlan(daysPerWeek: _days, place: _place, level: _level, focus: _focus);
    return _page0([
      _title(t, 'Tu rutina', 'Te preparo una para empezar. Luego la puedes cambiar o crear otra con IA.'),
      _label(t, '¿Cuántos días a la semana?'),
      _choices(const [2, 3, 4, 5], _days, (v) => '$v días', (v) => _days = v),
      _label(t, '¿Dónde entrenas?'),
      for (final p in StarterPlace.values)
        Card(
          color: _place == p ? FmColors.lavender : null,
          child: ListTile(
            leading: Icon(
              _place == p ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
              color: FmColors.primary,
            ),
            title: Text(p.label),
            subtitle: Text(p.description),
            onTap: () => setState(() => _place = p),
          ),
        ),
      _label(t, 'Tu nivel'),
      _choices(StarterLevel.values, _level, (v) => v.label, (v) => _level = v),
      if (_days >= 3) ...[
        _label(t, '¿Qué quieres trabajar más?'),
        _choices(StarterFocus.values, _focus, (v) => v.label, (v) => _focus = v),
      ],
      const SizedBox(height: 16),
      Card(
        color: FmColors.lavender,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tu semana', style: t.titleSmall?.copyWith(color: FmColors.ink)),
              const SizedBox(height: 6),
              for (final d in plan.days.where((d) => d.isTraining))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    '${d.weekdayName}: ${d.title} · ${d.exercises.length} ejercicios',
                    style: t.bodyMedium?.copyWith(color: FmColors.ink),
                  ),
                ),
            ],
          ),
        ),
      ),
    ]);
  }

  // 3 · Hábitos
  Widget _habits(TextTheme t) => _page0([
        _title(t, 'Tus hábitos', 'Todo es opcional y orientativo.'),
        _label(t, 'Meta de agua'),
        Row(
          children: [
            IconButton.outlined(
              onPressed: _water > 4 ? () => setState(() => _water--) : null,
              icon: const Icon(Icons.remove_rounded),
            ),
            Expanded(child: Text('💧 $_water vasos al día', textAlign: TextAlign.center, style: t.titleMedium)),
            IconButton.outlined(
              onPressed: _water < 16 ? () => setState(() => _water++) : null,
              icon: const Icon(Icons.add_rounded),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Avisarme cuando toca entrenar'),
          value: _reminder,
          onChanged: (v) => setState(() => _reminder = v),
        ),
        if (_reminder)
          Row(
            children: [
              const Text('A las'),
              const SizedBox(width: 12),
              Expanded(
                child: Slider(
                  value: _reminderHour.toDouble(),
                  min: 6,
                  max: 22,
                  divisions: 16,
                  label: '$_reminderHour:00',
                  onChanged: (v) => setState(() => _reminderHour = v.round()),
                ),
              ),
              Text('$_reminderHour:00', style: t.titleMedium),
            ],
          ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Registrar comidas'),
          subtitle: const Text('Con tu mano como medida, sin pesar nada'),
          value: _meals,
          onChanged: (v) => setState(() => _meals = v),
        ),
      ]);

  // 4 · Privacidad
  Widget _privacy(TextTheme t) => _page0([
        _title(t, 'Tus datos son tuyos', '${_name.text.trim().isEmpty ? '' : '${_name.text.trim()}, '}antes de empezar:'),
        for (final (e, s) in const [
          ('📱', 'Todo se guarda solo en tu teléfono: no hay cuentas ni servidores.'),
          ('📸', 'Tus fotos de progreso nunca salen del teléfono, salvo que tú las compartas.'),
          ('💾', 'Haz una copia de seguridad de vez en cuando (Perfil → Copia de seguridad) para no perder nada si cambias de teléfono.'),
          ('🩺', 'Las cifras (IMC, calorías, descanso, ciclo) son orientativas, no un diagnóstico. Ante cualquier duda de salud, consulta a un profesional.'),
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 12),
                Expanded(child: Text(s, style: t.bodyLarge)),
              ],
            ),
          ),
      ]);
}
