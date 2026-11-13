import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app_scope.dart';
import '../../../core/models/exercise.dart';
import '../../../core/models/plan.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/ids.dart';
import '../../../shared/widgets/common.dart';
import '../../evolution/domain/muscle_map.dart';
import '../domain/ai_plan.dart';

/// Armar la rutina con una IA gratuita copiando y pegando: la app arma la pregunta,
/// la persona la pega en el chat que prefiera y luego pega aquí la respuesta.
class AiPlanScreen extends StatefulWidget {
  const AiPlanScreen({super.key, this.focus = const {}});

  /// Zonas a priorizar preseleccionadas (por ejemplo, desde las sugerencias del mapa muscular).
  final Set<MuscleGroup> focus;

  @override
  State<AiPlanScreen> createState() => _AiPlanScreenState();
}

class _AiPlanScreenState extends State<AiPlanScreen> {
  AiGoal _goal = AiGoal.tonificar;
  AiLevel _level = AiLevel.principiante;
  int _minutes = 45;
  Set<int>? _days;
  Set<Equipment> _equipment = {Equipment.mancuernas, Equipment.esterilla, Equipment.pesoCorporal};
  late Set<MuscleGroup> _focus = {...widget.focus};
  final _notes = TextEditingController();
  final _answer = TextEditingController();
  bool _includeHistory = true;
  bool _copied = false;
  AiPlanResult? _result;
  String? _error;

  static const _chats = [
    ('ChatGPT', 'https://chatgpt.com/'),
    ('Gemini', 'https://gemini.google.com/app'),
    ('Claude', 'https://claude.ai/new'),
  ];

  @override
  void dispose() {
    _notes.dispose();
    _answer.dispose();
    super.dispose();
  }

  AiPlanRequest _request(AppScope scope) {
    Map<MuscleGroup, double>? summary;
    if (_includeHistory) {
      final m = trainingMap(scope.history.sessions, scope.library.byId, TrainingPeriod.mes, DateTime.now());
      summary = {
        for (final s in m.stats.values)
          if (s.muscle != MuscleGroup.cardio) s.muscle: s.sets / m.weeks,
      };
    }
    return AiPlanRequest(
      goal: _goal,
      weekdays: _days!,
      minutes: _minutes,
      level: _level,
      equipment: _equipment,
      focus: _focus,
      notes: _notes.text,
      trainingSummary: summary,
    );
  }

  Future<void> _copy(AppScope scope) async {
    if (_days!.isEmpty) {
      _snack('Elige al menos un día para entrenar.');
      return;
    }
    await Clipboard.setData(ClipboardData(text: buildAiPrompt(_request(scope), scope.library.all)));
    setState(() => _copied = true);
    _snack('Pregunta copiada. Ábrela en tu chat de IA y pégala.');
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) setState(() => _answer.text = data!.text!);
  }

  void _review(AppScope scope) {
    try {
      final r = parseAiPlan(_answer.text, scope.library.all, newId: newId);
      setState(() {
        _result = r;
        _error = null;
      });
    } on AiParseException catch (e) {
      setState(() {
        _result = null;
        _error = e.message;
      });
    }
  }

  Future<void> _use(AppScope scope) async {
    final r = _result!;
    await scope.plans.addAndActivate(r.plan);
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Rutina "${r.plan.name}" activada. La anterior sigue guardada en Editar rutina.'),
    ));
  }

  void _snack(String s) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final t = Theme.of(context).textTheme;
    _days ??= {...scope.plans.trainingWeekdays};
    const letters = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

    return Scaffold(
      appBar: AppBar(title: const Text('Rutina con IA')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
        children: [
          Card(
            color: FmColors.lavender,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                'Gratis y sin cuentas: 1) eliges lo que quieres, 2) copias la pregunta y la pegas en ChatGPT, '
                'Gemini o Claude, 3) pegas aquí la respuesta y la app crea la rutina con tus ejercicios.\n\n'
                'Nada se envía solo: tú decides qué compartes. La pregunta no incluye tu nombre, fotos ni medidas.',
                style: t.bodyMedium,
              ),
            ),
          ),
          const SectionTitle('1. ¿Qué quieres?'),
          Text('Objetivo', style: t.titleSmall),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final g in AiGoal.values)
                ChoiceChip(label: Text(g.label), selected: _goal == g, onSelected: (_) => setState(() => _goal = g)),
            ],
          ),
          const SizedBox(height: 14),
          Text('Días para entrenar', style: t.titleSmall),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var d = 1; d <= 7; d++)
                FilterChip(
                  showCheckmark: false,
                  label: Text(letters[d - 1]),
                  tooltip: weekdayNames[d - 1],
                  selected: _days!.contains(d),
                  onSelected: (v) => setState(() => v ? _days!.add(d) : _days!.remove(d)),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text('Tiempo por sesión', style: t.titleSmall),
          const SizedBox(height: 6),
          SegmentedButton<int>(
            showSelectedIcon: false,
            segments: [for (final m in [20, 30, 45, 60]) ButtonSegment(value: m, label: Text('$m min'))],
            selected: {_minutes},
            onSelectionChanged: (v) => setState(() => _minutes = v.first),
          ),
          const SizedBox(height: 14),
          Text('Nivel', style: t.titleSmall),
          const SizedBox(height: 6),
          SegmentedButton<AiLevel>(
            showSelectedIcon: false,
            segments: [for (final l in AiLevel.values) ButtonSegment(value: l, label: Text(l.label))],
            selected: {_level},
            onSelectionChanged: (v) => setState(() => _level = v.first),
          ),
          const SizedBox(height: 14),
          Text('Equipo que tienes', style: t.titleSmall),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final q in Equipment.values)
                FilterChip(
                  label: Text(q.label),
                  selected: _equipment.contains(q),
                  onSelected: (v) => setState(() => _equipment = v ? {..._equipment, q} : ({..._equipment}..remove(q))),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text('Zonas a priorizar (opcional)', style: t.titleSmall),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final m in MuscleGroup.values)
                FilterChip(
                  label: Text(m.label),
                  selected: _focus.contains(m),
                  onSelected: (v) => setState(() => _focus = v ? {..._focus, m} : ({..._focus}..remove(m))),
                ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _notes,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Notas o limitaciones (opcional)',
              hintText: 'Ej. me molesta la rodilla, prefiero no saltar',
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _includeHistory,
            onChanged: (v) => setState(() => _includeHistory = v),
            title: const Text('Incluir lo que he entrenado'),
            subtitle: const Text('Solo las series por músculo del último mes'),
          ),
          const SectionTitle('2. Copia la pregunta y pégala en la IA'),
          FilledButton.icon(
            onPressed: () => _copy(scope),
            icon: Icon(_copied ? Icons.check_rounded : Icons.copy_rounded),
            label: Text(_copied ? 'COPIADA · COPIAR DE NUEVO' : 'COPIAR PREGUNTA'),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final (i, (name, url)) in _chats.indexed) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
                    child: Text(name),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text('Abre el chat que prefieras, mantén pulsado el cuadro de texto y elige "Pegar".',
              style: t.bodySmall?.copyWith(color: FmColors.muted)),
          const SectionTitle('3. Pega aquí la respuesta'),
          TextField(
            controller: _answer,
            minLines: 4,
            maxLines: 8,
            decoration: InputDecoration(
              hintText: 'Pega aquí todo lo que respondió la IA',
              suffixIcon: IconButton(
                tooltip: 'Pegar',
                icon: const Icon(Icons.content_paste_rounded),
                onPressed: _paste,
              ),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () async {
              if (_answer.text.trim().isEmpty) await _paste();
              if (_answer.text.trim().isNotEmpty) _review(scope);
            },
            icon: const Icon(Icons.fact_check_rounded),
            label: const Text('Revisar rutina'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Card(
              color: (FmColors.dark ? const Color(0xFF3D2228) : const Color(0xFFFFEDEE)),
              child: Padding(padding: const EdgeInsets.all(14), child: Text(_error!)),
            ),
          ],
          if (_result != null) ..._preview(context, scope, _result!),
        ],
      ),
    );
  }

  List<Widget> _preview(BuildContext context, AppScope scope, AiPlanResult r) {
    final t = Theme.of(context).textTheme;
    final training = r.plan.days.where((d) => d.isTraining).toList();
    return [
      SectionTitle(r.plan.name),
      Text(
          '${training.length} ${training.length == 1 ? 'día' : 'días'} de entrenamiento · '
          '${r.exerciseCount} ${r.exerciseCount == 1 ? 'ejercicio' : 'ejercicios'}',
          style: t.bodyMedium?.copyWith(color: FmColors.muted)),
      const SizedBox(height: 8),
      for (final d in r.plan.days)
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(d.isTraining || d.title == 'Descanso' ? '${d.weekdayName} · ${d.title}' : d.weekdayName,
                    style: t.titleSmall),
                if (!d.isTraining)
                  Text(d.title == 'Descanso' ? 'Recuperación' : 'Descanso · ${d.title}',
                      style: t.bodySmall?.copyWith(color: FmColors.muted))
                else
                  for (final e in d.exercises)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '• ${scope.library.byId(e.exerciseId)?.name ?? e.exerciseId} — ${e.sets} × ${e.target.label}'
                        '${e.restSeconds == null ? '' : ' · descanso ${e.restSeconds} s'}',
                        style: t.bodyMedium,
                      ),
                    ),
              ],
            ),
          ),
        ),
      if (r.warnings.isNotEmpty) ...[
        const SizedBox(height: 4),
        for (final w in r.warnings) Text('⚠️ $w', style: t.bodySmall),
      ],
      if (r.tips.isNotEmpty) ...[
        const SectionTitle('Consejos de la IA'),
        for (final tip in r.tips)
          Padding(padding: const EdgeInsets.only(bottom: 4), child: Text('• $tip', style: t.bodyMedium)),
        Text('Son sugerencias generales: escucha a tu cuerpo y ajusta lo que necesites.',
            style: t.bodySmall?.copyWith(color: FmColors.muted)),
      ],
      const SizedBox(height: 16),
      FilledButton.icon(
        onPressed: () => _use(scope),
        icon: const Icon(Icons.check_rounded),
        label: const Text('USAR ESTA RUTINA'),
      ),
      const SizedBox(height: 6),
      Text('Tu rutina actual no se borra: podrás volver a ella desde Editar rutina.',
          style: t.bodySmall?.copyWith(color: FmColors.muted), textAlign: TextAlign.center),
    ];
  }
}
