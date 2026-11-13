import 'core/utils/gender.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_scope.dart';
import 'features/evolution/evolution_screen.dart';
import 'features/goals/domain/achievements.dart';
import 'features/goals/domain/rewards.dart';
import 'features/goals/ui/achievements_screen.dart';
import 'features/goals/state/rewards_service.dart';
import 'features/home/home_screen.dart';
import 'features/home_widgets/home_widget_sync.dart';
import 'features/steps/steps_log.dart';
import 'features/pet/pet_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/workout/ui/workout_tab_screen.dart';

/// Navegación principal: Inicio · Entrenar · Mi evolución · Mi mascota · Mi perfil.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

/// Pestaña abierta: sobrevive a la reconstrucción al cambiar de tema.
int _lastTab = 0;

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int _index = _lastTab;
  RewardsService? _rewards;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkWidgetLaunch();
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncSteps());
  }

  /// Copia los pasos del podómetro y recalcula puntos y retos si cambiaron.
  Future<void> _syncSteps() async {
    if (!mounted) return;
    final scope = AppScope.of(context);
    if (await StepsLog.sync(scope.store)) await scope.rewards.refresh();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkWidgetLaunch();
      HomeWidgetSync.takeWidgetWater(AppScope.of(context).habits);
      _syncSteps();
    }
  }

  /// Si la app se abrió desde un widget de la pantalla de inicio, va a la pestaña que corresponde.
  Future<void> _checkWidgetLaunch() async {
    if (!HomeWidgetSync.supported) return;
    try {
      final s = await const MethodChannel('fitmakyp/launch').invokeMethod<String>('takeUri');
      if (s == null || !mounted) return;
      if (s.startsWith(widgetUriTrain)) _goTo(1);
      if (s.startsWith(widgetUriPet)) _goTo(3);
    } on PlatformException catch (e) {
      debugPrint('Widget: $e');
    } on MissingPluginException {
      // Sin canal nativo (pruebas o web).
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final r = AppScope.of(context).rewards;
    if (!identical(r, _rewards)) {
      _rewards?.removeListener(_celebrate);
      _rewards = r..addListener(_celebrate);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _rewards?.removeListener(_celebrate);
    super.dispose();
  }

  /// Muestra un aviso cuando se cumple una meta.
  void _celebrate() {
    if (!mounted) return;
    for (final a in _rewards?.takeJustUnlocked() ?? const <Achievement>[]) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${a.emoji} ¡Nueva insignia! ${context.g(a.title)}${a.points > 0 ? ' · +${a.points} puntos' : ''}'),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Ver',
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AchievementsScreen())),
        ),
      ));
    }
    final done = _rewards?.takeJustCompleted() ?? const [];
    if (done.isEmpty) return;
    for (final g in done) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('🏆 ¡Meta cumplida! ${g.title} · +${PointRules.goal} puntos'),
        duration: const Duration(seconds: 4),
      ));
    }
  }

  void _goTo(int i) => setState(() => _index = _lastTab = i);

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(onOpenTab: _goTo),
      const WorkoutTabScreen(),
      const EvolutionScreen(),
      const PetScreen(),
      const ProfileScreen(),
    ];
    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _goTo,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Inicio'),
          NavigationDestination(
              icon: Icon(Icons.fitness_center_outlined), selectedIcon: Icon(Icons.fitness_center), label: 'Entrenar'),
          NavigationDestination(
              icon: Icon(Icons.insights_outlined), selectedIcon: Icon(Icons.insights_rounded), label: 'Evolución'),
          NavigationDestination(icon: Icon(Icons.pets_outlined), selectedIcon: Icon(Icons.pets), label: 'Mascota'),
          NavigationDestination(
              icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded), label: 'Perfil'),
        ],
      ),
    );
  }
}
