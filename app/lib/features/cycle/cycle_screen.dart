import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import 'cycle_store.dart';
import 'domain/cycle.dart';

const _months = ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'];
String _dm(DateTime d) => '${d.day} de ${_months[d.month - 1]}';

/// Mi ciclo: día y fase, próxima regla, síntomas de hoy, calendario y ánimo por fase.
class CycleScreen extends StatefulWidget {
  const CycleScreen({super.key});

  @override
  State<CycleScreen> createState() => _CycleScreenState();
}

class _CycleScreenState extends State<CycleScreen> {
  late CycleStore _c;
  bool _init = false;
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_init) return;
    _init = true;
    _c = CycleStore(AppScope.of(context).store);
  }

  Future<void> _run(Future<void> Function() f) async {
    await f();
    if (mounted) setState(() {});
  }

  Future<void> _pickStart() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
      helpText: '¿Qué día te bajó?',
    );
    if (d != null) _run(() => _c.startPeriod(d));
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final now = DateTime.now();
    final st = _c.status;
    final phase = st.phaseOn(now);
    final day = st.cycleDay(now);
    final inPeriod = st.periodOn(now) != null;
    final until = st.daysUntilNext(now);
    final today = _c.dayOn(now);

    return Scaffold(
      appBar: AppBar(title: const Text('Mi ciclo')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        children: [
          // Resumen
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: !st.hasData
                  ? Column(
                      children: [
                        const Text('🌸', style: TextStyle(fontSize: 48)),
                        const SizedBox(height: 8),
                        Text('Registra tu última regla', style: t.titleLarge),
                        const SizedBox(height: 6),
                        Text(
                          'Con eso te muestro en qué fase estás, cuándo podría llegar la siguiente y cómo adaptar tus entrenos.',
                          textAlign: TextAlign.center,
                          style: t.bodyMedium?.copyWith(color: FmColors.muted),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        SizedBox(
                          width: 120,
                          height: 120,
                          child: CustomPaint(
                            painter: _CycleRing(day: day ?? 1, length: math.max(st.avgCycle, day ?? 1), periodDays: st.avgPeriod),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('Día', style: t.labelMedium?.copyWith(color: FmColors.muted)),
                                  Text('${day ?? '-'}', style: t.displaySmall?.copyWith(fontWeight: FontWeight.w800, color: FmColors.ink)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (phase != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: phase.color.withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text('${phase.emoji} ${phase.label}', style: t.labelLarge?.copyWith(color: FmColors.ink)),
                                ),
                              const SizedBox(height: 8),
                              Text(
                                inPeriod
                                    ? 'Tienes la regla'
                                    : until == null
                                        ? ''
                                        : until > 1
                                            ? 'Próxima regla en ~$until días'
                                            : until >= 0
                                                ? 'La regla podría llegar ${until == 0 ? 'hoy' : 'mañana'}'
                                                : 'Va con ${-until} ${-until == 1 ? 'día' : 'días'} de retraso',
                                style: t.titleMedium,
                              ),
                              if (!inPeriod && st.nextStart != null)
                                Text('Hacia el ${_dm(st.nextStart!)}', style: t.bodySmall?.copyWith(color: FmColors.muted)),
                              const SizedBox(height: 4),
                              Text(
                                st.cycleCount == 0
                                    ? 'Ciclo de 28 días (por defecto hasta tener más datos)'
                                    : 'Tu ciclo medio: ${st.avgCycle} días · regla de ${st.avgPeriod}',
                                style: t.bodySmall?.copyWith(color: FmColors.muted),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 10),
          if (inPeriod)
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
              onPressed: () => _run(() => _c.endPeriod(now)),
              icon: const Icon(Icons.check_rounded),
              label: const Text('Mi regla terminó hoy'),
            )
          else
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      backgroundColor: const Color(0xFFE5737A),
                    ),
                    onPressed: () => _run(() => _c.startPeriod(now)),
                    icon: const Text('🩸'),
                    label: const Text('Me bajó hoy'),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 50)),
                  onPressed: _pickStart,
                  child: const Text('Otro día'),
                ),
              ],
            ),

          // Entreno según la fase
          if (phase != null) ...[
            const SizedBox(height: 14),
            Card(
              color: phase.color.withValues(alpha: FmColors.dark ? 0.22 : 0.14),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('💪 Entrenar en esta fase', style: t.titleSmall?.copyWith(color: FmColors.ink)),
                    const SizedBox(height: 4),
                    Text(phase.tip, style: t.bodyMedium?.copyWith(color: FmColors.ink)),
                    const SizedBox(height: 4),
                    Text('Cada cuerpo es distinto: tómalo como guía, no como regla.',
                        style: t.bodySmall?.copyWith(color: FmColors.muted)),
                  ],
                ),
              ),
            ),
          ],

          // Hoy
          const SizedBox(height: 18),
          Text('¿Cómo estás hoy?', style: t.titleMedium),
          const SizedBox(height: 8),
          if (inPeriod) ...[
            Text('Flujo', style: t.labelLarge?.copyWith(color: FmColors.muted)),
            const SizedBox(height: 6),
            SegmentedButton<int>(
              showSelectedIcon: false,
              segments: [for (var i = 0; i < flowLabels.length; i++) ButtonSegment(value: i, label: Text(flowLabels[i]))],
              selected: {today.flow},
              onSelectionChanged: (v) => _run(() => _c.setDay(now, CycleDay(flow: v.first, symptoms: today.symptoms))),
            ),
            const SizedBox(height: 10),
          ],
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final s in Symptom.values)
                FilterChip(
                  label: Text('${s.emoji} ${s.label}'),
                  selected: today.symptoms.contains(s),
                  onSelected: (on) => _run(() => _c.setDay(
                        now,
                        CycleDay(
                          flow: today.flow,
                          symptoms: on ? {...today.symptoms, s} : ({...today.symptoms}..remove(s)),
                        ),
                      )),
                ),
            ],
          ),

          // Calendario
          const SizedBox(height: 18),
          Row(
            children: [
              IconButton(
                tooltip: 'Mes anterior',
                onPressed: () => setState(() => _month = DateTime(_month.year, _month.month - 1)),
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Expanded(
                child: Text(
                  '${_months[_month.month - 1][0].toUpperCase()}${_months[_month.month - 1].substring(1)} ${_month.year}',
                  textAlign: TextAlign.center,
                  style: t.titleMedium,
                ),
              ),
              IconButton(
                tooltip: 'Mes siguiente',
                onPressed: () => setState(() => _month = DateTime(_month.year, _month.month + 1)),
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          _MonthGrid(month: _month, status: st, store: _c),
          const SizedBox(height: 6),
          Wrap(
            spacing: 14,
            runSpacing: 4,
            children: [
              _legend(const Color(0xFFE5737A), 'Regla'),
              _legend(const Color(0xFFE5737A).withValues(alpha: 0.3), 'Estimada'),
              _legend(CyclePhase.ovulatoria.color, 'Ovulación aprox.'),
            ],
          ),

          // Ánimo por fase
          ..._moodByPhase(t, st),

          // Historial
          if (st.periods.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text('Mis reglas', style: t.titleMedium),
            const SizedBox(height: 6),
            Card(
              child: Column(
                children: [
                  for (final (i, p) in st.periods.reversed.take(8).indexed)
                    ListTile(
                      dense: true,
                      leading: const Text('🩸'),
                      title: Text('${formatShortDate(p.start)}${p.end != null ? ' – ${formatShortDate(p.end!)}' : ' (en curso)'}'),
                      subtitle: Text([
                        if (p.length != null) '${p.length} días',
                        if (_cycleBefore(st.periods, st.periods.length - 1 - i) case final c?) 'ciclo de $c días',
                      ].join(' · ')),
                      trailing: IconButton(
                        tooltip: 'Borrar',
                        icon: const Icon(Icons.delete_outline_rounded, size: 20),
                        onPressed: () => _run(() => _c.deletePeriod(p)),
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            '🔒 Tu ciclo solo se guarda en tu teléfono (y en tus copias de seguridad). No se incluye en el reporte ni en lo que copias para la IA. '
            'Las fechas son estimaciones y no sirven como método anticonceptivo.',
            style: t.bodySmall?.copyWith(color: FmColors.muted),
          ),
        ],
      ),
    );
  }

  /// Días entre la regla [j] y la anterior.
  static int? _cycleBefore(List<Period> ps, int j) {
    if (j <= 0) return null;
    final a = ps[j - 1].start, b = ps[j].start;
    return DateTime.utc(b.year, b.month, b.day).difference(DateTime.utc(a.year, a.month, a.day)).inDays;
  }

  Widget _legend(Color c, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 12, height: 12, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      );

  List<Widget> _moodByPhase(TextTheme t, CycleStatus st) {
    final checks = AppScope.of(context).body.checkins;
    final mood = averageByPhase(st, [for (final c in checks) (c.date, c.mood)]);
    final energy = averageByPhase(st, [for (final c in checks) (c.date, c.energy)]);
    if (mood.isEmpty) {
      return [
        const SizedBox(height: 18),
        Card(
          child: ListTile(
            leading: const Text('🎭', style: TextStyle(fontSize: 24)),
            title: const Text('Tu ánimo en cada fase'),
            subtitle: const Text(
                'Haz tu registro diario (Evolución) unos días y aquí verás cómo cambian tu ánimo y tu energía a lo largo del ciclo.'),
          ),
        ),
      ];
    }
    return [
      const SizedBox(height: 18),
      Text('Tu ánimo y energía en cada fase', style: t.titleMedium),
      const SizedBox(height: 6),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              for (final ph in CyclePhase.values)
                if (mood[ph] != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        SizedBox(width: 130, child: Text('${ph.emoji} ${ph.label}', style: t.bodySmall)),
                        Expanded(child: _bar(mood[ph]!, ph.color)),
                        SizedBox(
                          width: 92,
                          child: Text(
                            'ánimo ${mood[ph]!.toStringAsFixed(1).replaceAll('.', ',')}'
                            '${energy[ph] != null ? '\nenergía ${energy[ph]!.toStringAsFixed(1).replaceAll('.', ',')}' : ''}',
                            textAlign: TextAlign.right,
                            style: t.labelSmall,
                          ),
                        ),
                      ],
                    ),
                  ),
              const SizedBox(height: 4),
              Text('Escala 1 a 5, según tus registros diarios.', style: t.labelSmall?.copyWith(color: FmColors.muted)),
            ],
          ),
        ),
      ),
    ];
  }

  Widget _bar(double v, Color c) => ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: LinearProgressIndicator(value: v / 5, minHeight: 10, color: c, backgroundColor: FmColors.line),
      );
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({required this.month, required this.status, required this.store});
  final DateTime month;
  final CycleStatus status;
  final CycleStore store;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final first = DateTime(month.year, month.month, 1);
    final days = DateTime(month.year, month.month + 1, 0).day;
    final offset = first.weekday - 1;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final ov = status.ovulation;
    const red = Color(0xFFE5737A);
    return Column(
      children: [
        Row(
          children: [
            for (final d in ['L', 'M', 'X', 'J', 'V', 'S', 'D'])
              Expanded(child: Center(child: Text(d, style: t.labelSmall?.copyWith(color: FmColors.muted)))),
          ],
        ),
        const SizedBox(height: 4),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
          children: [
            for (var i = 0; i < offset; i++) const SizedBox(),
            for (var n = 1; n <= days; n++)
              Builder(builder: (_) {
                final d = DateTime(month.year, month.month, n);
                final real = !d.isAfter(today) && status.periodOn(d) != null;
                final predicted = status.predictedPeriodOn(d);
                final isOv = ov != null && d.year == ov.year && d.month == ov.month && d.day == ov.day && d.isAfter(today);
                final noted = store.dayOn(d).symptoms.isNotEmpty;
                return Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: real
                        ? red
                        : predicted
                            ? red.withValues(alpha: 0.3)
                            : isOv
                                ? CyclePhase.ovulatoria.color.withValues(alpha: 0.6)
                                : null,
                    border: d == today ? Border.all(color: FmColors.primary, width: 2) : null,
                  ),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$n',
                        style: t.labelMedium?.copyWith(
                          color: real ? Colors.white : FmColors.ink,
                          fontWeight: d == today ? FontWeight.w800 : null,
                        ),
                      ),
                      if (noted)
                        Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(color: real ? Colors.white : FmColors.primary, shape: BoxShape.circle),
                        ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ],
    );
  }
}

/// Anillo del ciclo: tramo de regla, ovulación aproximada y dónde estás hoy.
class _CycleRing extends CustomPainter {
  _CycleRing({required this.day, required this.length, required this.periodDays});
  final int day;
  final int length;
  final int periodDays;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Rect.fromCircle(center: size.center(Offset.zero), radius: size.width / 2 - 8);
    double a(num d) => -math.pi / 2 + 2 * math.pi * d / length;
    Paint arc(Color c) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.butt;
    canvas.drawArc(r, 0, 2 * math.pi, false, arc(CyclePhase.folicular.color.withValues(alpha: 0.35)));
    final ov = length - 14;
    canvas.drawArc(r, a(ov - 2), a(ov + 2) - a(ov - 2), false, arc(CyclePhase.ovulatoria.color));
    canvas.drawArc(r, a(ov + 2), a(length) - a(ov + 2), false, arc(CyclePhase.lutea.color.withValues(alpha: 0.45)));
    canvas.drawArc(r, a(0), a(periodDays) - a(0), false, arc(CyclePhase.menstrual.color));
    final m = a(day - 0.5);
    final p = r.center + Offset(math.cos(m), math.sin(m)) * r.width / 2;
    canvas.drawCircle(p, 10, Paint()..color = Colors.white);
    canvas.drawCircle(p, 7, Paint()..color = FmColors.deep);
  }

  @override
  bool shouldRepaint(_CycleRing o) => o.day != day || o.length != length || o.periodDays != periodDays;
}
