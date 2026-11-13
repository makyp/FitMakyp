import 'package:flutter/material.dart';

import '../../../app_scope.dart';
import '../../../core/models/body.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';

/// Registro diario opcional: ánimo, energía, descanso, actividad y comentario.
Future<void> showCheckinSheet(BuildContext context) => showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: FmColors.surface,
      builder: (_) => const _CheckinSheet(),
    );

class _CheckinSheet extends StatefulWidget {
  const _CheckinSheet();

  @override
  State<_CheckinSheet> createState() => _CheckinSheetState();
}

class _CheckinSheetState extends State<_CheckinSheet> {
  late DailyCheckin _c;
  final _comment = TextEditingController();
  bool _init = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_init) return;
    _init = true;
    _c = AppScope.of(context).body.checkinFor(DateTime.now()) ?? DailyCheckin(date: dateOnly(DateTime.now()));
    _comment.text = _c.comment;
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  DailyCheckin _with({int? mood, int? energy, int? sleep, int? activity}) => DailyCheckin(
        date: _c.date,
        mood: mood ?? _c.mood,
        energy: energy ?? _c.energy,
        sleep: sleep ?? _c.sleep,
        activity: activity ?? _c.activity,
        comment: _comment.text.trim(),
      );

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    Widget row(String label, List<String> faces, int value, ValueChanged<int> onPick) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: t.titleSmall),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (var i = 1; i <= 5; i++)
                    InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => onPick(i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 52,
                        height: 46,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: value == i ? FmColors.lavender : FmColors.warmWhite,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: value == i ? FmColors.primary : FmColors.line, width: 1.5),
                        ),
                        child: Text(faces[i - 1], style: const TextStyle(fontSize: 22)),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );

    const moods = ['😞', '😕', '😐', '🙂', '😄'];
    const levels = ['1', '2', '3', '4', '5'];
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('¿Cómo te sientes hoy?', style: t.titleLarge),
            const SizedBox(height: 4),
            Text('Opcional. Sin fotos, sin presión.', style: t.bodySmall?.copyWith(color: FmColors.muted)),
            const SizedBox(height: 16),
            row('Estado de ánimo', moods, _c.mood, (v) => setState(() => _c = _with(mood: v))),
            row('Energía (1-5)', levels, _c.energy, (v) => setState(() => _c = _with(energy: v))),
            row('Calidad del descanso (1-5)', levels, _c.sleep, (v) => setState(() => _c = _with(sleep: v))),
            row('Actividad (1-5)', levels, _c.activity, (v) => setState(() => _c = _with(activity: v))),
            TextField(
              controller: _comment,
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Comentario (opcional)'),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () async {
                await AppScope.of(context).body.saveCheckin(_with());
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('GUARDAR'),
            ),
          ],
        ),
      ),
    );
  }
}
