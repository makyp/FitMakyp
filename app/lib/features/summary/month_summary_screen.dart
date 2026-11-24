import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';

import '../../app_scope.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../shared/widgets/pet_avatar.dart';
import '../challenges/domain/challenges.dart';
import '../morning/morning_log.dart';

const _monthNames = ['Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'];

/// Mes que se muestra por defecto: el anterior durante los primeros 5 días, si no el actual.
DateTime defaultSummaryMonth(DateTime now) =>
    now.day <= 5 ? DateTime(now.year, now.month - 1) : DateTime(now.year, now.month);

/// Datos del mes (todo calculado con lo que ya registras).
class MonthStats {
  const MonthStats({
    required this.workouts,
    required this.minutes,
    required this.sets,
    required this.mornings,
    required this.waterDays,
    required this.checkins,
    required this.moodAvg,
    required this.perfectWeeks,
    required this.challenges,
    required this.bestStreak,
  });
  final int workouts;
  final int minutes;
  final int sets;
  final int mornings;
  final int waterDays;
  final int checkins;
  final double? moodAvg;
  final int perfectWeeks;
  final int challenges;
  final int bestStreak;
}

MonthStats monthStats(BuildContext context, DateTime month) {
  final s = AppScope.of(context);
  bool inMonth(DateTime d) => d.year == month.year && d.month == month.month;
  final sessions = s.history.sessions.where((x) => inMonth(x.startedAt) && x.completedSets > 0).toList();
  final checks = s.body.checkins.where((c) => inMonth(c.date)).toList();
  final input = s.rewards.challenges;
  var perfect = 0, done = 0;
  for (var m = weekStart(DateTime(month.year, month.month, 1));
      m.month == month.month || m.isBefore(DateTime(month.year, month.month, 1));
      m = DateTime(m.year, m.month, m.day + 7)) {
    // Semanas que terminan dentro del mes.
    final end = DateTime(m.year, m.month, m.day + 6);
    if (!inMonth(end)) continue;
    final st = weekStatus(m, input);
    done += st.where((x) => x.done).length;
    if (st.every((x) => x.done)) perfect++;
  }
  // Mejor racha de días seguidos entrenando dentro del mes.
  final days = {for (final x in sessions) dateOnly(x.startedAt)}.toList()..sort();
  var best = 0, run = 0;
  DateTime? prev;
  for (final d in days) {
    run = prev != null && d.difference(prev).inHours <= 26 ? run + 1 : 1;
    if (run > best) best = run;
    prev = d;
  }
  return MonthStats(
    workouts: sessions.length,
    minutes: sessions.fold<int>(0, (a, x) => a + x.activeDuration(x.finishedAt ?? x.startedAt).inMinutes),
    sets: sessions.fold(0, (a, x) => a + x.completedSets),
    mornings: MorningLog.days(s.store).where(inMonth).length,
    waterDays: s.habits.waterGoalDays.where(inMonth).length,
    checkins: checks.length,
    moodAvg: checks.isEmpty ? null : checks.fold<int>(0, (a, c) => a + c.mood) / checks.length,
    perfectWeeks: perfect,
    challenges: done,
    bestStreak: best,
  );
}

/// "Mi mes": una tarjeta bonita para guardar o compartir.
class MonthSummaryScreen extends StatefulWidget {
  const MonthSummaryScreen({super.key});

  @override
  State<MonthSummaryScreen> createState() => _MonthSummaryScreenState();
}

class _MonthSummaryScreenState extends State<MonthSummaryScreen> {
  late DateTime _month = defaultSummaryMonth(DateTime.now());
  final _card = GlobalKey();
  bool _sharing = false;

  void _shift(int delta) {
    final next = DateTime(_month.year, _month.month + delta);
    if (next.isAfter(DateTime.now())) return;
    setState(() => _month = next);
  }

  Future<void> _share() async {
    setState(() => _sharing = true);
    try {
      final b = _card.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final img = await b.toImage(pixelRatio: 3);
      final png = await img.toByteData(format: ui.ImageByteFormat.png);
      final name = 'FitMakyp_${_monthNames[_month.month - 1]}_${_month.year}.png';
      await SharePlus.instance.share(ShareParams(
        files: [XFile.fromData(png!.buffer.asUint8List(), name: name, mimeType: 'image/png')],
        fileNameOverrides: [name],
      ));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo crear la imagen: $e')));
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final now = DateTime.now();
    final canNext = DateTime(_month.year, _month.month + 1).isBefore(DateTime(now.year, now.month + 1));
    return Scaffold(
      appBar: AppBar(title: const Text('Mi mes')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Row(
            children: [
              IconButton(tooltip: 'Mes anterior', onPressed: () => _shift(-1), icon: const Icon(Icons.chevron_left_rounded)),
              Expanded(
                child: Text('${_monthNames[_month.month - 1]} ${_month.year}', textAlign: TextAlign.center, style: t.titleMedium),
              ),
              IconButton(
                tooltip: 'Mes siguiente',
                onPressed: canNext ? () => _shift(1) : null,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          RepaintBoundary(key: _card, child: MonthCard(month: _month, stats: monthStats(context, _month))),
          const SizedBox(height: 16),
          FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            onPressed: _sharing ? null : _share,
            icon: const Icon(Icons.ios_share_rounded),
            label: const Text('GUARDAR O COMPARTIR IMAGEN'),
          ),
          const SizedBox(height: 6),
          Text(
            'Se crea una imagen en tu teléfono; tú eliges dónde guardarla o con quién compartirla. No incluye tu peso, medidas, fotos ni ciclo.',
            style: t.bodySmall?.copyWith(color: FmColors.muted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class MonthCard extends StatelessWidget {
  const MonthCard({super.key, required this.month, required this.stats});
  final DateTime month;
  final MonthStats stats;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final s = stats;
    final tiles = <(String, String, String)>[
      ('💪', '${s.workouts}', s.workouts == 1 ? 'entreno' : 'entrenos'),
      ('⏱️', formatDurationShort(Duration(minutes: s.minutes)), 'entrenando'),
      ('🔥', '${s.bestStreak}', 'días seguidos'),
      if (s.mornings > 0) ('🌅', '${s.mornings}', s.mornings == 1 ? 'mañana hipopresiva' : 'mañanas hipopresivas'),
      if (s.waterDays > 0) ('💧', '${s.waterDays}', 'días con meta de agua'),
      if (s.moodAvg != null) (_face(s.moodAvg!), s.moodAvg!.toStringAsFixed(1).replaceAll('.', ','), 'ánimo medio'),
      if (s.challenges > 0) ('🏆', '${s.challenges}', s.challenges == 1 ? 'reto cumplido' : 'retos cumplidos'),
    ];
    final headline = s.workouts == 0 && s.mornings == 0
        ? 'Un mes para empezar con calma 💜'
        : s.perfectWeeks > 0
            ? '¡${s.perfectWeeks} ${s.perfectWeeks == 1 ? 'semana perfecta' : 'semanas perfectas'}!'
            : s.workouts >= 12
                ? '¡Un mes imparable!'
                : '¡Cada paso cuenta!';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2B1B43), Color(0xFF7041B8), Color(0xFFB79CE6)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('MI MES EN FITMAKYP',
                        style: const TextStyle(color: Color(0xFFDCCBFA), fontSize: 11, letterSpacing: 1.6, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text('${_monthNames[month.month - 1]} ${month.year}',
                        style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text(headline, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              PetAvatar(size: 92, mood: PetMood.celebrating, look: scope.pet.look),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (_, c) {
              final w = (c.maxWidth - 10) / 2;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final (e, v, l) in tiles)
                    Container(
                      width: w,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Text(e, style: const TextStyle(fontSize: 22)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(v, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                                Text(l, style: const TextStyle(color: Color(0xFFEDE4FB), fontSize: 11), maxLines: 2),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Text('${scope.pet.name} · nivel ${scope.rewards.level}',
                  style: const TextStyle(color: Color(0xFFEDE4FB), fontSize: 12, fontWeight: FontWeight.w600)),
              const Spacer(),
              const Text('FitMakyp 💜', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
            ],
          ),
        ],
      ),
    );
  }

  static String _face(double v) => const ['😞', '😕', '😐', '🙂', '😄'][(v.round() - 1).clamp(0, 4)];
}
