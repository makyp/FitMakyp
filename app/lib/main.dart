import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app_scope.dart';
import 'core/notifications/reminders.dart';
import 'core/notifications/rest_alarm.dart';
import 'core/sound/timer_sounds.dart';
import 'core/sound/voice_coach.dart';
import 'core/storage/local_store.dart';
import 'core/storage/photo_store.dart';
import 'core/theme/app_theme.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/evolution/state/body_repository.dart';
import 'features/goals/state/goals_repository.dart';
import 'features/goals/state/rewards_service.dart';
import 'features/habits/state/habits_repository.dart';
import 'features/habits/state/reminder_sync.dart';
import 'features/history/state/history_repository.dart';
import 'features/home_widgets/home_widget_sync.dart';
import 'features/library/state/library_repository.dart';
import 'features/pet/state/pet_repository.dart';
import 'features/plans/state/plan_repository.dart';
import 'features/settings/state/settings_repository.dart';
import 'features/workout/state/workout_controller.dart';
import 'home_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final alarm = await LocalNotificationsRestAlarm.create();
  // Permiso de notificaciones (descanso, agua y evaluación). Android solo lo pregunta una vez.
  alarm.requestPermission();
  // Los sonidos se preparan en segundo plano: nunca retrasan el arranque.
  runApp(AppRoot(alarm: alarm, sounds: LazyTimerSounds(AudioTimerSounds.create)));
}

ReminderSync? _reminderSync;
final VoiceCoach _voice = TtsVoiceCoach();
HomeWidgetSync? _widgetSync;

/// Crea todos los servicios a partir del almacenamiento local.
Future<AppScope Function(Widget child, Future<void> Function() restart)> _buildServices({
  required RestAlarm alarm,
  required TimerSounds sounds,
}) async {
  final store = await LocalStore.open();
  await skipOnboardingForExistingUser(store);
  final photos = await PhotoStore.create(store);
  final settings = SettingsRepository(store);
  final library = LibraryRepository(store);
  final plans = PlanRepository(store);
  final history = HistoryRepository(store);
  final body = BodyRepository(store, photos);
  final goals = GoalsRepository(store);
  final pet = PetRepository(store);
  final habits = HabitsRepository(store);
  final rewards = RewardsService(
    history: history,
    body: body,
    goals: goals,
    pet: pet,
    plans: plans,
    habits: habits,
    store: store,
  );
  _reminderSync?.dispose();
  _reminderSync = ReminderSync(
    habits: habits,
    body: body,
    plans: plans,
    history: history,
    pet: pet,
    reminders: kIsWeb ? NoopReminders() : LocalReminders(),
    store: store,
    settings: settings,
  );
  final workout = WorkoutController(
    store: store,
    history: history,
    library: library,
    settings: settings,
    alarm: alarm,
    sounds: sounds,
    voice: _voice,
  );
  _widgetSync?.dispose();
  _widgetSync = HomeWidgetSync(
    plans: plans,
    history: history,
    habits: habits,
    pet: pet,
    workout: workout,
    rewards: rewards,
  );
  return (child, restart) => AppScope(
        store: store,
        settings: settings,
        library: library,
        plans: plans,
        history: history,
        workout: workout,
        body: body,
        goals: goals,
        pet: pet,
        rewards: rewards,
        habits: habits,
        onRestart: restart,
        child: child,
      );
}

class AppRoot extends StatefulWidget {
  const AppRoot({super.key, required this.alarm, required this.sounds});
  final RestAlarm alarm;
  final TimerSounds sounds;

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  AppScope Function(Widget, Future<void> Function())? _scope;
  Key _appKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await _buildServices(alarm: widget.alarm, sounds: widget.sounds);
    if (mounted) {
      setState(() {
        _scope = s;
        _appKey = UniqueKey(); // reinicia la navegación
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = _scope;
    if (scope == null) {
      return ColoredBox(color: FmColors.warmWhite);
    }
    return scope(FitMakypApp(key: _appKey), _load);
  }
}

class FitMakypApp extends StatelessWidget {
  const FitMakypApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = AppScope.of(context).settings;
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final mode = settings.settings.themeMode;
        final dark = mode == 'oscuro' || (mode == 'sistema' && MediaQuery.platformBrightnessOf(context) == Brightness.dark);
        // Los colores de la app dependen del tema: al cambiarlo se reconstruye todo (la pestaña se recuerda).
        return _app(buildTheme(dark: dark), ValueKey(dark));
      },
    );
  }

  Widget _app(ThemeData theme, Key key) {
    return MaterialApp(
      key: key,
      title: 'FitMakyp',
      debugShowCheckedModeBanner: false,
      theme: theme,
      locale: const Locale('es'),
      supportedLocales: const [Locale('es')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // En tablet/computadora la app se muestra con ancho de móvil, centrada.
      builder: (context, child) => ColoredBox(
        color: FmColors.dark ? const Color(0xFF0C0811) : const Color(0xFFEDE5F8),
        child: Center(
          child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 520), child: child),
        ),
      ),
      home: const _OnboardingGate(),
    );
  }
}


/// La primera vez muestra la bienvenida; después, la app.
class _OnboardingGate extends StatefulWidget {
  const _OnboardingGate();

  @override
  State<_OnboardingGate> createState() => _OnboardingGateState();
}

class _OnboardingGateState extends State<_OnboardingGate> {
  @override
  Widget build(BuildContext context) {
    final done = AppScope.of(context).store.readJson(onboardedKey) == true;
    return done ? const HomeShell() : OnboardingScreen(onDone: () => setState(() {}));
  }
}
