import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../morning/ui/morning_screen.dart';
import 'domain/sleep_estimate.dart';
import 'sleep_service.dart';

const _dayShort = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];

Color restColor(RestLevel l) => switch (l) {
      RestLevel.bueno => const Color(0xFF3FBF9F),
      RestLevel.justo => const Color(0xFFE5A54B),
      RestLevel.corto => const Color(0xFFE5737A),
    };

/// Mi descanso: horas sin usar el teléfono por la noche y primera activación.
class SleepScreen extends StatefulWidget {
  const SleepScreen({super.key});

  @override
  State<SleepScreen> createState() => _SleepScreenState();
}

class _SleepScreenState extends State<SleepScreen> with WidgetsBindingObserver {
  bool _loading = true;
  bool _access = false;
  List<NightRest> _nights = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Al volver de Ajustes, mirar si ya hay permiso.
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    final access = await SleepService.hasAccess();
    final nights = access ? await SleepService.nights() : null;
    if (!mounted) return;
    setState(() {
      _access = access;
      _nights = nights ?? const [];
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mi descanso')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : !SleepService.supported
              ? _message('Disponible en la app de Android', 'En el navegador no se puede saber cuándo usas el teléfono.')
              : !_access
                  ? _askAccess()
                  : _content(),
    );
  }

  Widget _message(String title, String text) {
    final t = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('🌙', style: TextStyle(fontSize: 56)),
          const SizedBox(height: 12),
          Text(title, style: t.titleLarge, textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(text, style: t.bodyMedium?.copyWith(color: FmColors.muted), textAlign: TextAlign.center),
        ]),
      ),
    );
  }

  Widget _askAccess() {
    final t = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Center(child: Text('🌙', style: TextStyle(fontSize: 64))),
        const SizedBox(height: 12),
        Text('Conoce tu descanso sin hacer nada', style: t.headlineSmall, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        Text(
          'FitMakyp puede estimar tus noches viendo cuánto tiempo pasas sin usar el teléfono '
          '(2 horas o más) y a qué hora lo usas por primera vez al despertar.',
          style: t.bodyLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 18),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('🔒  Tu privacidad', style: t.titleSmall),
                const SizedBox(height: 6),
                Text(
                  '• Solo se leen horas de uso, nunca qué apps ni qué haces.\n'
                  '• Todo se calcula y se queda en tu teléfono.\n'
                  '• Puedes quitar el permiso cuando quieras en Ajustes.',
                  style: t.bodyMedium,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          onPressed: SleepService.openSettings,
          icon: const Icon(Icons.settings_rounded),
          label: const Text('ACTIVAR EN AJUSTES'),
        ),
        const SizedBox(height: 8),
        Text(
          'En la lista, busca FitMakyp y activa "Permitir acceso al uso". Luego vuelve aquí.',
          style: t.bodySmall?.copyWith(color: FmColors.muted),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _content() {
    final t = Theme.of(context).textTheme;
    final scope = AppScope.of(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final last = _nights.isNotEmpty && _nights.first.morning == today ? _nights.first : null;
    final week = RestSummary(_nights.take(7).toList());
    final checks = scope.body.checkins.where((c) => now.difference(c.date).inDays < 7).toList();
    final rating = checks.isEmpty ? null : checks.fold<int>(0, (a, c) => a + c.sleep) / checks.length;
    final morningDone = MorningLog.doneOn(scope.store, now);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                colors: [Color(0xFF1B1430), Color(0xFF4A2F7D)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: last == null
                ? Text(
                    'Aún no hay datos de anoche. Si acabas de activar el permiso, vuelve mañana 🌙',
                    style: t.bodyLarge?.copyWith(color: Colors.white),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('ANOCHE', style: TextStyle(color: Color(0xFFDCCBFA), fontWeight: FontWeight.w800, letterSpacing: 1.4, fontSize: 12)),
                      const SizedBox(height: 4),
                      Text(formatHm(last.offPhone), style: t.displaySmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                      Text('sin usar el teléfono · ${last.level.emoji} ${last.level.label}',
                          style: t.bodyLarge?.copyWith(color: Colors.white)),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          _pill('🌙 Último uso', formatTime(last.lastUse)),
                          const SizedBox(width: 10),
                          _pill('☀️ Primera activación', formatTime(last.firstUse)),
                        ],
                      ),
                    ],
                  ),
          ),
          if (last != null && !morningDone && now.hour < 13) ...[
            const SizedBox(height: 12),
            Card(
              color: FmColors.lavender,
              child: ListTile(
                leading: const Text('🌅', style: TextStyle(fontSize: 26)),
                title: Text('Te activaste a las ${formatTime(last.firstUse)}', style: TextStyle(color: FmColors.ink, fontWeight: FontWeight.w700)),
                subtitle: Text('¿Hacemos la rutina matutina antes del desayuno?', style: TextStyle(color: FmColors.ink)),
                trailing: Icon(Icons.play_circle_fill_rounded, color: FmColors.primary, size: 32),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MorningScreen())),
              ),
            ),
          ],
          const SizedBox(height: 18),
          Text('Últimas noches', style: t.titleMedium),
          const SizedBox(height: 8),
          if (week.isEmpty)
            Text('Todavía no hay noches con 2 horas o más sin usar el teléfono.', style: t.bodyMedium?.copyWith(color: FmColors.muted))
          else
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
                child: Column(
                  children: [
                    for (final n in week.nights)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 34,
                              child: Text(_dayShort[n.morning.weekday - 1], style: t.labelLarge),
                            ),
                            Expanded(
                              child: LayoutBuilder(
                                builder: (_, c) => Stack(
                                  children: [
                                    Container(
                                      height: 22,
                                      decoration: BoxDecoration(color: FmColors.line, borderRadius: BorderRadius.circular(8)),
                                    ),
                                    Container(
                                      height: 22,
                                      width: c.maxWidth * (n.offPhone.inMinutes / 600).clamp(0.05, 1.0),
                                      decoration: BoxDecoration(color: restColor(n.level), borderRadius: BorderRadius.circular(8)),
                                    ),
                                    // Referencia de 7 h
                                    Positioned(
                                      left: c.maxWidth * 0.7,
                                      top: 0,
                                      bottom: 0,
                                      child: Container(width: 2, color: FmColors.ink.withValues(alpha: 0.35)),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 92,
                              child: Text(
                                '${formatHm(n.offPhone)}\n${formatTime(n.lastUse)}–${formatTime(n.firstUse)}',
                                style: t.labelSmall,
                                textAlign: TextAlign.right,
                              ),
                            ),
                          ],
                        ),
                      ),
                    Text('La línea marca 7 horas', style: t.labelSmall?.copyWith(color: FmColors.muted)),
                  ],
                ),
              ),
            ),
          if (!week.isEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _stat(formatHm(week.average), 'promedio sin teléfono')),
                const SizedBox(width: 10),
                Expanded(child: _stat(formatClockMinutes(week.averageWake!), 'primera activación media')),
                const SizedBox(width: 10),
                Expanded(child: _stat(formatClockMinutes(week.averageLastUse!), 'último uso medio')),
              ],
            ),
            if (week.wakeSpread != null) ...[
              const SizedBox(height: 10),
              Text(
                week.wakeSpread! <= 30
                    ? '⏰ Te activas a horas parecidas (±${week.wakeSpread} min). ¡La regularidad ayuda mucho al descanso!'
                    : '⏰ Tu hora de activación cambia bastante (±${week.wakeSpread} min). Intentar levantarte a una hora parecida ayuda.',
                style: t.bodyMedium,
              ),
            ],
          ],
          if (rating != null) ...[
            const SizedBox(height: 10),
            Text('Tu valoración del descanso esta semana: ${rating.toStringAsFixed(1).replaceAll('.', ',')} de 5',
                style: t.bodyMedium),
          ],
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Ideas para descansar mejor', style: t.titleSmall),
                  const SizedBox(height: 6),
                  Text(
                    '• Deja el teléfono 30–60 min antes de dormir.\n'
                    '• Al despertar, empieza con agua y tu rutina matutina antes de mirar la pantalla.\n'
                    '• Intenta acostarte y levantarte a horas parecidas, también el fin de semana.',
                    style: t.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Es una estimación: el tiempo sin usar el teléfono no es exactamente tu sueño. Si algo te preocupa del descanso, consúltalo con un profesional.',
            style: t.bodySmall?.copyWith(color: FmColors.muted),
          ),
          Text('Actualizado ${formatShortDate(now)} ${formatTime(now)}', style: t.bodySmall?.copyWith(color: FmColors.muted)),
        ],
      ),
    );
  }

  Widget _pill(String label, String value) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Color(0xFFDCCBFA), fontSize: 11)),
              Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      );

  Widget _stat(String value, String label) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(color: FmColors.lavender, borderRadius: BorderRadius.circular(14)),
      child: Column(
        children: [
          Text(value, style: t.titleMedium?.copyWith(color: FmColors.ink, fontWeight: FontWeight.w800)),
          Text(label, style: t.labelSmall?.copyWith(color: FmColors.ink), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
