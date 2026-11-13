import 'package:flutter/material.dart';

import '../../../app_scope.dart';
import '../../../core/models/body.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/progress_analysis.dart';

/// IMC actual, su categoría (referencia OMS para adultos), cambios y rango de referencia.
class BmiCard extends StatelessWidget {
  const BmiCard({super.key});

  @override
  Widget build(BuildContext context) {
    final body = AppScope.of(context).body;
    return ListenableBuilder(
      listenable: body,
      builder: (context, _) {
        final t = Theme.of(context).textTheme;
        final h = body.heightCm;
        final weights = body.series(Measure.peso);
        if (h == null) {
          return Card(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              leading: Icon(Icons.height_rounded, color: FmColors.primary),
              title: const Text('Añade tu estatura para ver tu IMC'),
              subtitle: const Text('También hace la silueta más fiel a tu cuerpo'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => editHeight(context),
            ),
          );
        }
        if (weights.isEmpty) {
          return const Card(child: ListTile(title: Text('Registra tu peso para calcular tu IMC.')));
        }
        final current = bmi(weights.last.$2, h);
        final cat = bmiCategory(current);
        final first = bmi(weights.first.$2, h);
        final monthRef = _monthAgoWeight(weights);
        final (lo, hi) = healthyWeightRange(h);

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(current.toStringAsFixed(1), style: t.headlineMedium),
                    const SizedBox(width: 6),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text('IMC', style: t.titleSmall?.copyWith(color: FmColors.muted)),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: cat.color.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: cat.color),
                      ),
                      child: Text(cat.label, style: t.labelLarge?.copyWith(fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _BmiGauge(value: current),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(child: _Change(label: 'Desde el inicio', value: current - first)),
                    if (monthRef != null) Expanded(child: _Change(label: 'Último mes', value: current - bmi(monthRef, h))),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Con ${h.round()} cm, el IMC 18,5-24,9 corresponde a unos ${lo.toStringAsFixed(1)}-${hi.toStringAsFixed(1)} kg.',
                  style: t.bodyMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'El IMC es solo una referencia general: no distingue músculo de grasa ni tiene en cuenta tu '
                  'composición corporal. Si entrenas fuerza, tus medidas y cómo te sientes dicen más. '
                  'Para una valoración personal, consulta a un profesional de la salud.',
                  style: t.bodySmall?.copyWith(color: FmColors.muted),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => editHeight(context),
                    icon: const Icon(Icons.edit_rounded, size: 16),
                    label: Text('Estatura: ${h.round()} cm'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static double? _monthAgoWeight(List<(DateTime, double)> w) {
    if (w.length < 2) return null;
    final target = w.last.$1.subtract(const Duration(days: 30));
    (DateTime, double)? best;
    for (final p in w.sublist(0, w.length - 1)) {
      if (best == null || p.$1.difference(target).abs() < best.$1.difference(target).abs()) best = p;
    }
    return best?.$2;
  }
}

Future<void> editHeight(BuildContext context) async {
  final body = AppScope.of(context).body;
  final ctrl = TextEditingController(text: body.heightCm?.round().toString() ?? '');
  final v = await showDialog<double>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Tu estatura'),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(suffixText: 'cm', hintText: 'Ej. 162'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () {
            final x = double.tryParse(ctrl.text.trim().replaceAll(',', '.'));
            if (x != null && x >= 120 && x <= 230) Navigator.pop(ctx, x);
          },
          child: const Text('Guardar'),
        ),
      ],
    ),
  );
  if (v != null) await body.setHeight(v);
}

class _Change extends StatelessWidget {
  const _Change({required this.label, required this.value});
  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final s = value > 0.05 ? '+' : (value < -0.05 ? '−' : '');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: t.labelMedium?.copyWith(color: FmColors.muted)),
        Text('$s${value.abs().toStringAsFixed(1)} de IMC', style: t.titleSmall),
      ],
    );
  }
}

/// Barra de 15 a 35 con los rangos coloreados y un marcador en el valor actual.
class _BmiGauge extends StatelessWidget {
  const _BmiGauge({required this.value});
  final double value;

  static const _min = 15.0, _max = 35.0;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return LayoutBuilder(
      builder: (context, c) {
        double x(double v) => ((v.clamp(_min, _max) - _min) / (_max - _min)) * c.maxWidth;
        return Column(
          children: [
            SizedBox(
              height: 26,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    top: 8,
                    left: 0,
                    right: 0,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Row(
                        children: [
                          for (final cat in BmiCategory.values)
                            Expanded(
                              flex: ((cat.max.clamp(_min, _max) - cat.min.clamp(_min, _max)) * 10).round(),
                              child: Container(height: 10, color: cat.color),
                            ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: x(value) - 7,
                    top: 0,
                    child: Container(
                      width: 14,
                      height: 26,
                      decoration: BoxDecoration(
                        color: FmColors.deep,
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Stack(
              children: [
                const SizedBox(height: 16, width: double.infinity),
                for (final v in [18.5, 25.0, 30.0])
                  Positioned(left: x(v) - 12, child: Text(v.toStringAsFixed(v % 1 == 0 ? 0 : 1), style: t.labelSmall)),
              ],
            ),
          ],
        );
      },
    );
  }
}
