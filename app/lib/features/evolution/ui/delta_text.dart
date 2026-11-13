import 'package:flutter/material.dart';

import '../../../core/models/body.dart';
import '../../../core/theme/app_theme.dart';

/// Diferencia entre dos valores ("−2,5 cm · −3,1 %"). Color neutro: la app no juzga los cambios.
class DeltaText extends StatelessWidget {
  const DeltaText({super.key, required this.delta, required this.unit});
  final MeasureDelta delta;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final d = delta.diff;
    final sign = d > 0 ? '+' : (d < 0 ? '−' : '');
    final abs = d.abs();
    final value = abs == abs.roundToDouble() ? abs.round().toString() : abs.toStringAsFixed(1);
    final pct = delta.percent;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          d > 0 ? Icons.arrow_upward_rounded : (d < 0 ? Icons.arrow_downward_rounded : Icons.remove_rounded),
          size: 16,
          color: FmColors.primary,
        ),
        const SizedBox(width: 2),
        Text.rich(
          TextSpan(children: [
            TextSpan(text: '$sign$value $unit', style: const TextStyle(fontWeight: FontWeight.w800)),
            if (pct != null && d != 0)
              TextSpan(text: '  $sign${pct.abs().toStringAsFixed(1)} %', style: TextStyle(color: FmColors.muted)),
          ]),
          style: t.bodyMedium?.copyWith(color: FmColors.ink),
        ),
      ],
    );
  }
}
