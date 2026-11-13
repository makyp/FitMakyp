import '../morning/ui/morning_screen.dart';
import '../sleep/domain/sleep_estimate.dart';
import '../sleep/sleep_service.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../app_scope.dart';
import '../../core/models/body.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../shared/widgets/common.dart';
import 'report_data.dart';
import 'report_pdf.dart';

/// Reporte en PDF para enseñar al entrenador. Se genera en el teléfono y se comparte
/// solo si la usuaria lo decide (WhatsApp, correo, guardar en archivos…).
class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  ReportPeriod _period = ReportPeriod.mes;
  bool _photos = false;
  bool _busy = false;
  final _notes = TextEditingController();

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  ReportData _data() {
    final s = AppScope.of(context);
    final streak = s.history.streak(s.plans.trainingWeekdays);
    return buildReportData(
      name: s.settings.settings.userName,
      period: _period,
      now: DateTime.now(),
      sessions: s.history.sessions,
      exerciseById: s.library.byId,
      trainingWeekdays: s.plans.trainingWeekdays,
      records: s.body.records,
      checkins: s.body.checkins,
      currentStreak: streak.current,
      bestStreak: streak.best,
      notes: _notes.text,
    );
  }

  /// Primera y última foto de cada ángulo dentro del periodo (o la última anterior como "antes").
  Future<List<ReportPhoto>> _loadPhotos(ReportData d) async {
    final body = AppScope.of(context).body;
    final recs = body.records.where((r) => r.hasPhotos).toList();
    if (recs.isEmpty) return const [];
    final out = <ReportPhoto>[];
    for (final angle in PhotoAngle.values) {
      final withA = recs.where((r) => r.photos[angle] != null).toList();
      if (withA.isEmpty) continue;
      final before = withA.where((r) => dateOnly(r.date).isBefore(d.from)).toList();
      final first = before.isNotEmpty ? before.last : withA.first;
      final last = withA.last;
      for (final r in {first, last}) {
        final bytes = await body.photos.load(r.photos[angle]!);
        if (bytes != null) out.add(ReportPhoto('${angle.label} · ${formatShortDate(r.date)}', bytes));
      }
    }
    return out;
  }

  Future<void> _share() async {
    setState(() => _busy = true);
    try {
      final d = _data();
      final store = AppScope.of(context).store;
      final photos = _photos ? await _loadPhotos(d) : const <ReportPhoto>[];
      final nights = await SleepService.nights();
      final inPeriod = (nights ?? const <NightRest>[]).where((n) => !n.morning.isBefore(dateOnly(d.from))).toList();
      final bytes = await renderReportPdf(
        d,
        photos: photos,
        rest: inPeriod.isEmpty ? null : RestSummary(inPeriod),
        mornings: MorningLog.countBetween(store, d.from, d.to),
      );
      final t = DateTime.now();
      final name = 'FitMakyp_reporte_${t.year}${t.month.toString().padLeft(2, '0')}${t.day.toString().padLeft(2, '0')}.pdf';
      await SharePlus.instance.share(ShareParams(
        files: [XFile.fromData(bytes, name: name, mimeType: 'application/pdf')],
        fileNameOverrides: [name],
        subject: 'Mi progreso en FitMakyp',
      ));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo crear el reporte: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final d = _data();
    final hasPhotos = AppScope.of(context).body.records.any((r) => r.hasPhotos);
    return Scaffold(
      appBar: AppBar(title: const Text('Reporte para mi entrenador')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          Text('Un PDF con tu progreso para enseñarlo a tu entrenador. Se crea en tu teléfono y tú eliges con quién compartirlo.',
              style: t.bodyMedium?.copyWith(color: FmColors.muted)),
          const SizedBox(height: 16),
          SegmentedButton<ReportPeriod>(
            showSelectedIcon: false,
            segments: [for (final p in ReportPeriod.values) ButtonSegment(value: p, label: Text(p.short))],
            selected: {_period},
            onSelectionChanged: (v) => setState(() => _period = v.first),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: StatTile(value: '${d.workouts.length}', label: 'Entrenos')),
              const SizedBox(width: 10),
              Expanded(child: StatTile(value: d.adherencePct == null ? '-' : '${d.adherencePct} %', label: 'Constancia')),
              const SizedBox(width: 10),
              Expanded(child: StatTile(value: '${d.totalSets}', label: 'Series')),
            ],
          ),
          const SectionTitle('Incluye'),
          Card(
            child: Column(
              children: [
                _Includes(icon: Icons.fitness_center_rounded, text: 'Entrenamientos, series y constancia'),
                _Includes(icon: Icons.local_fire_department_outlined, text: 'Si calentaste y estiraste'),
                _Includes(icon: Icons.accessibility_new_rounded, text: 'Series por músculo (${d.muscleSets.length} músculos)'),
                _Includes(icon: Icons.trending_up_rounded, text: 'Fuerza: peso máximo y comparación (${d.strength.length} ejercicios)'),
                _Includes(icon: Icons.straighten_rounded, text: 'Medidas: inicio y actual (${d.measures.length})'),
                _Includes(icon: Icons.mood_rounded, text: 'Ánimo, energía y sueño (${d.checkins} registros)'),
                SwitchListTile(
                  secondary: Icon(Icons.photo_library_outlined, color: FmColors.primary),
                  title: const Text('Incluir fotos de progreso'),
                  subtitle: Text(hasPhotos ? 'Primera y última de cada ángulo. Desactivado por privacidad.' : 'Aún no tienes fotos.'),
                  value: _photos && hasPhotos,
                  onChanged: hasPhotos ? (v) => setState(() => _photos = v) : null,
                ),
              ],
            ),
          ),
          const SectionTitle('Notas para el entrenador (opcional)'),
          TextField(
            controller: _notes,
            minLines: 3,
            maxLines: 6,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(hintText: 'Ej.: me molestó la rodilla el jueves; quiero priorizar glúteos.'),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _busy ? null : _share,
            icon: _busy
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                : const Icon(Icons.ios_share_rounded),
            label: Text(_busy ? 'CREANDO…' : 'CREAR Y COMPARTIR PDF'),
          ),
        ],
      ),
    );
  }
}

class _Includes extends StatelessWidget {
  const _Includes({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => ListTile(
        dense: true,
        leading: Icon(icon, color: FmColors.primary),
        title: Text(text),
      );
}
