import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app_scope.dart';
import '../../../core/models/habits.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/progress_photo.dart';
import '../domain/hand_portions.dart';

/// Añadir o editar una comida. Se puede registrar "con la mano" (sin pesar nada)
/// o con números. Todo es opcional y orientativo.
Future<void> showMealSheet(BuildContext context, {required DateTime day, MealEntry? existing}) =>
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: FmColors.surface,
      builder: (_) => _MealSheet(day: day, existing: existing),
    );

MealType _typeForHour(int h) => h < 11
    ? MealType.desayuno
    : h < 16
        ? MealType.almuerzo
        : h < 19
            ? MealType.snack
            : MealType.cena;

class _MealSheet extends StatefulWidget {
  const _MealSheet({required this.day, this.existing});
  final DateTime day;
  final MealEntry? existing;

  @override
  State<_MealSheet> createState() => _MealSheetState();
}

class _MealSheetState extends State<_MealSheet> {
  late MealType _type = widget.existing?.type ?? _typeForHour(DateTime.now().hour);
  late final _desc = TextEditingController(text: widget.existing?.description);
  late final _kcal = TextEditingController(
    text: widget.existing?.portions == null ? widget.existing?.kcal?.toString() : null,
  );
  late final _protein = TextEditingController(
    text: widget.existing?.portions == null ? widget.existing?.protein?.toString() : null,
  );
  late HandPortions _portions = widget.existing?.portions ?? const HandPortions();
  late String? _photoId = widget.existing?.photoId;

  /// Fotos hechas en esta hoja (se borran si no se guarda).
  final _newPhotos = <String>{};
  bool _saved = false;

  /// true = con la mano (por defecto, salvo comidas antiguas registradas con números).
  late bool _hand = widget.existing == null ||
      widget.existing!.portions != null ||
      (widget.existing!.kcal == null && widget.existing!.protein == null);
  String? _error;

  late final _photos = AppScope.of(context).body.photos;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _photos; // se guarda la referencia para poder limpiar al cerrar
  }

  @override
  void dispose() {
    for (final c in [_desc, _kcal, _protein]) {
      c.dispose();
    }
    if (!_saved) {
      for (final id in _newPhotos) {
        _photos.delete(id);
      }
    }
    super.dispose();
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final f = await ImagePicker().pickImage(source: source, maxWidth: 1080, imageQuality: 80);
      if (f == null || !mounted) return;
      final id = await _photos.save(await f.readAsBytes());
      _newPhotos.add(id);
      setState(() => _photoId = id);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo usar la foto: $e')));
    }
  }

  Widget _photoSection(TextTheme t) {
    if (_photoId != null) {
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(height: 150, width: double.infinity, child: ProgressPhoto(key: ValueKey(_photoId), photoId: _photoId!)),
          ),
          Positioned(
            right: 6,
            top: 6,
            child: IconButton.filledTonal(
              tooltip: 'Quitar foto',
              onPressed: () => setState(() => _photoId = null),
              icon: const Icon(Icons.close_rounded),
            ),
          ),
        ],
      );
    }
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _pickPhoto(kIsWeb ? ImageSource.gallery : ImageSource.camera),
            icon: const Icon(Icons.photo_camera_outlined),
            label: const Text('Foto del plato'),
          ),
        ),
        if (!kIsWeb) ...[
          const SizedBox(width: 8),
          IconButton.outlined(
            tooltip: 'Desde la galería',
            onPressed: () => _pickPhoto(ImageSource.gallery),
            icon: const Icon(Icons.photo_library_outlined),
          ),
        ],
      ],
    );
  }

  int? _int(TextEditingController c) => int.tryParse(c.text.trim());

  Future<void> _save() async {
    if (_desc.text.trim().isEmpty) {
      setState(() => _error = 'Escribe qué comiste (con pocas palabras basta).');
      return;
    }
    int? kcal;
    int? protein;
    HandPortions? portions;
    if (_hand) {
      if (!_portions.isEmpty) {
        portions = _portions;
        kcal = _portions.kcal;
        protein = _portions.protein;
      }
    } else {
      kcal = _int(_kcal);
      protein = _int(_protein);
      if ((kcal != null && (kcal < 0 || kcal > 5000)) || (protein != null && (protein < 0 || protein > 400))) {
        setState(() => _error = 'Revisa los números.');
        return;
      }
    }
    final now = DateTime.now();
    final at = widget.existing?.at ??
        DateTime(widget.day.year, widget.day.month, widget.day.day, now.hour, now.minute);
    await AppScope.of(context).habits.saveMeal(
          id: widget.existing?.id,
          at: at,
          type: _type,
          description: _desc.text.trim(),
          kcal: kcal,
          protein: protein,
          portions: portions,
          photoId: _photoId,
        );
    _saved = true;
    // Borrar fotos que ya no se usan.
    for (final id in {..._newPhotos, ?widget.existing?.photoId}) {
      if (id != _photoId) await _photos.delete(id);
    }
    if (mounted) Navigator.pop(context);
  }

  void _repeat(MealEntry m) => setState(() {
        _desc.text = m.description;
        if (m.portions != null) {
          _hand = true;
          _portions = m.portions!;
        } else {
          _kcal.text = m.kcal?.toString() ?? '';
          _protein.text = m.protein?.toString() ?? '';
          if (m.kcal != null || m.protein != null) _hand = false;
        }
      });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final recent = AppScope.of(context).habits.recentMeals;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.existing == null ? 'Añadir comida' : 'Editar comida', style: t.titleLarge),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                for (final m in MealType.values)
                  ChoiceChip(
                    label: Text('${m.emoji} ${m.label}'),
                    selected: _type == m,
                    onSelected: (_) => setState(() => _type = m),
                  ),
              ],
            ),
            if (widget.existing == null && recent.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Repetir una reciente', style: t.labelLarge?.copyWith(color: FmColors.muted)),
              const SizedBox(height: 6),
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final m in recent)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ActionChip(
                          label: Text(m.description, overflow: TextOverflow.ellipsis),
                          onPressed: () => _repeat(m),
                        ),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _desc,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: '¿Qué comiste?',
                hintText: 'Ej.: arroz con pollo y ensalada',
                errorText: _error,
              ),
              onChanged: (_) => setState(() => _error = null),
            ),
            const SizedBox(height: 12),
            _photoSection(t),
            const SizedBox(height: 14),
            SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: true, label: Text('✋  Con mi mano')),
                ButtonSegment(value: false, label: Text('🔢  Con números')),
              ],
              selected: {_hand},
              onSelectionChanged: (v) => setState(() => _hand = v.first),
            ),
            const SizedBox(height: 12),
            if (_hand) ..._handSection(t) else ..._numbersSection(),
            const SizedBox(height: 18),
            FilledButton(onPressed: _save, child: const Text('GUARDAR')),
            if (widget.existing != null)
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: Colors.red.shade400),
                onPressed: () async {
                  await AppScope.of(context).habits.deleteMeal(widget.existing!.id);
                  if (widget.existing!.photoId != null) await _photos.delete(widget.existing!.photoId!);
                  if (context.mounted) Navigator.pop(context);
                },
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Eliminar'),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _handSection(TextTheme t) => [
        Text(
          'Sin báscula ni tazas: tu mano es tu medida. Cuenta cuántas porciones había en tu plato.',
          style: t.bodySmall?.copyWith(color: FmColors.muted),
        ),
        const SizedBox(height: 8),
        for (final p in HandPortion.values)
          PortionRow(
            portion: p,
            value: _portions[p],
            onChanged: (v) => setState(() => _portions = _portions.withValue(p, v)),
          ),
        const SizedBox(height: 4),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Container(
            key: ValueKey(_portions.isEmpty),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(color: FmColors.lavender, borderRadius: BorderRadius.circular(14)),
            child: Text(
              _portions.isEmpty
                  ? 'Si no quieres contar nada, guarda solo la descripción. También vale 💜'
                  : '≈ ${_portions.protein} g de proteína · ≈ ${_portions.kcal} kcal (aproximado)',
              style: t.bodyMedium?.copyWith(color: FmColors.ink, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ];

  List<Widget> _numbersSection() => [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _protein,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Proteína (opcional)', suffixText: 'g'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _kcal,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Calorías (opc.)', suffixText: 'kcal'),
              ),
            ),
          ],
        ),
      ];
}

/// Fila de una porción: dibujo, ejemplo y contador de medias porciones.
class PortionRow extends StatelessWidget {
  const PortionRow({super.key, required this.portion, required this.value, required this.onChanged});
  final HandPortion portion;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final active = value > 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: active ? FmColors.primary : FmColors.line, width: active ? 1.5 : 1),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: FmColors.lavender, shape: BoxShape.circle),
              child: Text(portion.emoji, style: const TextStyle(fontSize: 26)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${portion.label} · ${portion.unit}', style: t.titleSmall),
                  Text(portion.hint, style: t.bodySmall?.copyWith(color: FmColors.muted, height: 1.2)),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Media porción menos',
              visualDensity: VisualDensity.compact,
              onPressed: value > 0 ? () => onChanged(value - 0.5) : null,
              icon: const Icon(Icons.remove_circle_outline_rounded),
            ),
            SizedBox(
              width: 28,
              child: Text(
                HandPortions.amount(value),
                textAlign: TextAlign.center,
                style: t.titleMedium?.copyWith(color: active ? FmColors.primary : FmColors.muted, fontWeight: FontWeight.w800),
              ),
            ),
            IconButton(
              tooltip: 'Media porción más',
              visualDensity: VisualDensity.compact,
              color: FmColors.primary,
              onPressed: value < 10 ? () => onChanged(value + 0.5) : null,
              icon: const Icon(Icons.add_circle_rounded),
            ),
          ],
        ),
      ),
    );
  }
}
