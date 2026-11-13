import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 24, 4, 10),
        child: Row(
          children: [
            Expanded(child: Text(text, style: Theme.of(context).textTheme.titleMedium)),
            ?trailing,
          ],
        ),
      );
}

/// Dato grande con etiqueta ("12 / Repeticiones").
class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.value, required this.label, this.highlight = false});
  final String value;
  final String label;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: highlight ? FmColors.lavender : FmColors.warmWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: highlight ? FmColors.lavender : FmColors.line),
      ),
      child: Column(
        children: [
          FittedBox(
            child: Text(value, style: t.headlineSmall?.copyWith(color: highlight ? FmColors.ink : FmColors.primary)),
          ),
          const SizedBox(height: 2),
          Text(label, textAlign: TextAlign.center, style: t.labelMedium?.copyWith(color: FmColors.muted)),
        ],
      ),
    );
  }
}

class EmptyHint extends StatelessWidget {
  const EmptyHint({super.key, required this.icon, required this.title, required this.text});
  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: FmColors.lavender, shape: BoxShape.circle),
            child: Icon(icon, size: 36, color: FmColors.primary),
          ),
          const SizedBox(height: 16),
          Text(title, style: t.titleLarge, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(text, style: t.bodyMedium?.copyWith(color: FmColors.muted), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
