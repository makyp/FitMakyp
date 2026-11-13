import 'package:flutter/material.dart';

import '../../../app_scope.dart';
import '../../../core/models/body.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/progress_photo.dart';
import 'delta_text.dart';

/// Compara dos registros: fotos lado a lado o con deslizador, y diferencias de cada medida.
class CompareScreen extends StatefulWidget {
  const CompareScreen({super.key});

  @override
  State<CompareScreen> createState() => _CompareScreenState();
}

class _CompareScreenState extends State<CompareScreen> {
  String? _beforeId;
  String? _afterId;
  PhotoAngle _angle = PhotoAngle.frontal;
  bool _slider = false;
  double _split = 0.5;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final records = AppScope.of(context).body.records;
    if (records.length < 2) {
      return Scaffold(
        appBar: AppBar(title: const Text('Comparar')),
        body: const Center(
          child: EmptyHint(
            icon: Icons.compare_rounded,
            title: 'Necesitas 2 registros',
            text: 'Cuando tengas al menos dos registros podrás compararlos aquí.',
          ),
        ),
      );
    }
    final before = records.firstWhere((r) => r.id == _beforeId, orElse: () => records.first);
    final after = records.firstWhere((r) => r.id == _afterId, orElse: () => records.last);
    final angles = PhotoAngle.values.where((a) => before.photos[a] != null || after.photos[a] != null).toList();
    final angle = angles.contains(_angle) ? _angle : (angles.isEmpty ? _angle : angles.first);
    final days = dateOnly(after.date).difference(dateOnly(before.date)).inDays;

    DropdownButtonFormField<String> picker(String label, ProgressRecord value, ValueChanged<String> onChanged) =>
        DropdownButtonFormField<String>(
          initialValue: value.id,
          isExpanded: true,
          decoration: InputDecoration(labelText: label, isDense: true),
          items: [
            for (final r in records)
              DropdownMenuItem(value: r.id, child: Text('${formatShortDate(r.date)} ${r.date.year}${r.hasPhotos ? ' 📷' : ''}')),
          ],
          onChanged: (v) => v == null ? null : onChanged(v),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Comparar')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          Row(
            children: [
              Expanded(child: picker('Antes', before, (v) => setState(() => _beforeId = v))),
              const SizedBox(width: 10),
              Expanded(child: picker('Después', after, (v) => setState(() => _afterId = v))),
            ],
          ),
          const SizedBox(height: 6),
          Text('$days días entre ambos registros', style: t.bodySmall?.copyWith(color: FmColors.muted)),
          const SectionTitle('Fotos'),
          if (angles.isEmpty)
            Text('Estos registros no tienen fotos.', style: t.bodyMedium?.copyWith(color: FmColors.muted))
          else ...[
            Row(
              children: [
                Expanded(
                  child: SegmentedButton<PhotoAngle>(
                    showSelectedIcon: false,
                    segments: [for (final a in angles) ButtonSegment(value: a, label: Text(a.label))],
                    selected: {angle},
                    onSelectionChanged: (v) => setState(() => _angle = v.first),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: _slider ? 'Lado a lado' : 'Deslizador',
                  onPressed: () => setState(() => _slider = !_slider),
                  icon: Icon(_slider ? Icons.view_column_rounded : Icons.compare_rounded),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_slider)
              _SliderCompare(
                before: before.photos[angle],
                after: after.photos[angle],
                split: _split,
                onChanged: (v) => setState(() => _split = v),
              )
            else
              Row(
                children: [
                  Expanded(child: _PhotoCard(id: before.photos[angle], label: formatShortDate(before.date))),
                  const SizedBox(width: 10),
                  Expanded(child: _PhotoCard(id: after.photos[angle], label: formatShortDate(after.date))),
                ],
              ),
          ],
          const SectionTitle('Cambios'),
          Card(
            child: Column(
              children: [
                for (final m in Measure.values)
                  if (before.values[m] != null && after.values[m] != null) ...[
                    ListTile(
                      dense: true,
                      title: Text(m.label),
                      subtitle: Text('${_f(before.values[m]!)} → ${_f(after.values[m]!)} ${m.unit}'),
                      trailing: DeltaText(delta: MeasureDelta(before.values[m]!, after.values[m]!), unit: m.unit),
                    ),
                  ],
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Las cifras son solo informativas: la app no saca conclusiones sobre tu salud.',
            style: t.bodySmall?.copyWith(color: FmColors.muted),
          ),
        ],
      ),
    );
  }

  static String _f(double v) => v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);
}

class _PhotoCard extends StatelessWidget {
  const _PhotoCard({required this.id, required this.label});
  final String? id;
  final String label;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          AspectRatio(
            aspectRatio: 3 / 4,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: id == null
                  ? ColoredBox(color: FmColors.line, child: Center(child: Text('Sin foto')))
                  : ProgressPhoto(photoId: id!),
            ),
          ),
          const SizedBox(height: 6),
          Text(label, style: Theme.of(context).textTheme.labelLarge),
        ],
      );
}

/// Las dos fotos superpuestas: arrastra para ver antes / después.
class _SliderCompare extends StatelessWidget {
  const _SliderCompare({required this.before, required this.after, required this.split, required this.onChanged});
  final String? before;
  final String? after;
  final double split;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget photo(String? id) =>
        id == null ? ColoredBox(color: FmColors.line, child: Center(child: Text('Sin foto'))) : ProgressPhoto(photoId: id);
    return AspectRatio(
      aspectRatio: 3 / 4,
      child: LayoutBuilder(
        builder: (context, c) => GestureDetector(
          onHorizontalDragUpdate: (d) => onChanged((d.localPosition.dx / c.maxWidth).clamp(0.0, 1.0)),
          onTapDown: (d) => onChanged((d.localPosition.dx / c.maxWidth).clamp(0.0, 1.0)),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              fit: StackFit.expand,
              children: [
                photo(after),
                ClipRect(clipper: _LeftClipper(split), child: photo(before)),
                Positioned(
                  left: c.maxWidth * split - 1.5,
                  top: 0,
                  bottom: 0,
                  child: Container(width: 3, color: Colors.white),
                ),
                Positioned(
                  left: c.maxWidth * split - 18,
                  top: c.maxHeight / 2 - 18,
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.code_rounded, color: FmColors.primary),
                  ),
                ),
                const Positioned(left: 8, top: 8, child: _Tag('Antes')),
                const Positioned(right: 8, top: 8, child: _Tag('Después')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LeftClipper extends CustomClipper<Rect> {
  _LeftClipper(this.split);
  final double split;
  @override
  Rect getClip(Size size) => Rect.fromLTWH(0, 0, size.width * split, size.height);
  @override
  bool shouldReclip(_LeftClipper old) => old.split != split;
}

class _Tag extends StatelessWidget {
  const _Tag(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(10)),
        child: Text(text, style: Theme.of(context).textTheme.labelSmall),
      );
}
