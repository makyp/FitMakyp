import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app_scope.dart';
import '../../../core/models/body.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/progress_photo.dart';
import '../domain/progress_analysis.dart';
import '../state/body_repository.dart';
import 'pose_camera_screen.dart';

/// Registrar (o editar) peso, medidas y fotos. Todos los campos son opcionales.
class RecordFormScreen extends StatefulWidget {
  const RecordFormScreen({super.key, this.recordId});
  final String? recordId;

  @override
  State<RecordFormScreen> createState() => _RecordFormScreenState();
}

class _RecordFormScreenState extends State<RecordFormScreen> {
  final _ctrl = {for (final m in Measure.values) m: TextEditingController()};
  final _note = TextEditingController();
  final _height = TextEditingController();
  final _photos = <PhotoAngle, String>{};
  DateTime _date = DateTime.now();
  bool _loaded = false;
  bool _saving = false;
  bool _showAll = false;
  bool _saved = false;

  /// Fotos añadidas en esta pantalla: si se sale sin guardar, se borran.
  final _newPhotoIds = <String>{};
  BodyRepository? _body;

  static const _primary = [Measure.peso, Measure.cintura, Measure.abdomen, Measure.cadera, Measure.gluteos];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _body = AppScope.of(context).body;
    if (_loaded) return;
    _loaded = true;
    final h = AppScope.of(context).body.heightCm;
    if (h != null) _height.text = _fmt(h);
    _height.addListener(() => setState(() {}));
    _ctrl[Measure.peso]!.addListener(() => setState(() {}));
    final r = widget.recordId == null ? null : AppScope.of(context).body.byId(widget.recordId!);
    if (r != null) {
      _date = r.date;
      for (final e in r.values.entries) {
        _ctrl[e.key]!.text = _fmt(e.value);
      }
      _photos.addAll(r.photos);
      _note.text = r.note;
      _showAll = r.values.keys.any((m) => !_primary.contains(m));
    }
  }

  @override
  void dispose() {
    if (!_saved) {
      for (final id in _newPhotoIds) {
        _body?.photos.delete(id);
      }
    }
    for (final c in [..._ctrl.values, _note, _height]) {
      c.dispose();
    }
    super.dispose();
  }

  static String _fmt(double v) => v == v.roundToDouble() ? v.round().toString() : v.toString();

  double? _parse(String s) => double.tryParse(s.trim().replaceAll(',', '.'));

  Future<void> _pickPhoto(PhotoAngle angle) async {
    final source = await showModalBottomSheet<Object>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!kIsWeb)
              ListTile(
                leading: Icon(Icons.accessibility_new_rounded, color: FmColors.primary),
                title: const Text('Foto con guía (recomendado)'),
                subtitle: const Text('Silueta y foto anterior para salir en la misma posición'),
                onTap: () => Navigator.pop(ctx, _guided),
              ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(kIsWeb ? 'Hacer foto' : 'Cámara normal'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Elegir de la galería o archivos'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            if (_photos[angle] != null)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded),
                title: const Text('Quitar foto'),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => _photos.remove(angle));
                },
              ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    if (source == _guided) {
      final body = AppScope.of(context).body;
      final prevId = _previousPhoto(angle);
      final prev = prevId == null ? null : await body.photos.load(prevId);
      if (!mounted) return;
      final bytes = await takeGuidedPhoto(context, angle, previous: prev);
      if (bytes == null || !mounted) return;
      final id = await body.savePhoto(bytes);
      _newPhotoIds.add(id);
      setState(() => _photos[angle] = id);
      return;
    }
    try {
      final file = await ImagePicker().pickImage(
        source: source as ImageSource,
        maxWidth: kIsWeb ? 900 : 1440,
        imageQuality: kIsWeb ? 70 : 85,
        preferredCameraDevice: CameraDevice.rear,
      );
      if (file == null || !mounted) return;
      final id = await AppScope.of(context).body.savePhoto(await file.readAsBytes());
      _newPhotoIds.add(id);
      setState(() => _photos[angle] = id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo obtener la foto: $e')));
      }
    }
  }

  static const _guided = 'guiada';

  /// Foto más reciente de ese ángulo en otro registro (anterior a esta fecha si la hay).
  String? _previousPhoto(PhotoAngle angle) {
    final recs = AppScope.of(context)
        .body
        .records
        .where((r) => r.id != widget.recordId && r.photos[angle] != null)
        .toList();
    if (recs.isEmpty) return null;
    final before = recs.where((r) => !r.date.isAfter(_date)).toList();
    return (before.isNotEmpty ? before.last : recs.last).photos[angle];
  }

  Future<void> _save() async {
    final hTxt = _height.text.trim();
    final h = hTxt.isEmpty ? null : _parse(hTxt);
    if (hTxt.isNotEmpty && (h == null || h < 120 || h > 230)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Revisa tu estatura (en cm, por ejemplo 162).')));
      return;
    }
    final values = <Measure, double>{};
    for (final e in _ctrl.entries) {
      final txt = e.value.text.trim();
      if (txt.isEmpty) continue;
      final v = _parse(txt);
      if (v == null || v <= 0 || v > 400) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Revisa el valor de ${e.key.label}.')));
        return;
      }
      values[e.key] = v;
    }
    if (values.isEmpty && _photos.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Añade al menos un dato o una foto.')));
      return;
    }
    setState(() => _saving = true);
    final body = AppScope.of(context).body;
    if (h != null && h != body.heightCm) await body.setHeight(h);
    if (!mounted) return;
    await AppScope.of(context).body.saveRecord(
          id: widget.recordId,
          date: _date,
          values: values,
          photoIds: Map.of(_photos),
          note: _note.text.trim(),
        );
    _saved = true;
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar registro?'),
        content: const Text('Se borrarán sus medidas y fotos de este teléfono. No se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await AppScope.of(context).body.deleteRecord(widget.recordId!);
    _saved = true; // sus fotos ya se borraron con el registro
    if (mounted) Navigator.pop(context);
  }

  /// IMC al momento con el peso y la estatura escritos.
  List<Widget> _bmiLine(TextTheme t) {
    final w = _parse(_ctrl[Measure.peso]!.text);
    final h = _parse(_height.text);
    if (w == null || h == null || w <= 0 || h < 120 || h > 230) return const [];
    final v = bmi(w, h);
    final c = bmiCategory(v);
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
        child: Row(
          children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: c.color, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text('IMC ${v.toStringAsFixed(1).replaceAll('.', ',')} · ${c.label}', style: t.bodyMedium),
            const SizedBox(width: 6),
            Text('(orientativo)', style: t.bodySmall?.copyWith(color: FmColors.muted)),
          ],
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final measures = _showAll ? Measure.values : _primary;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.recordId == null ? 'Registrar progreso' : 'Editar registro'),
        actions: [
          if (widget.recordId != null)
            IconButton(
              tooltip: 'Eliminar registro',
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: _delete,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          Card(
            child: ListTile(
              leading: Icon(Icons.event_rounded, color: FmColors.primary),
              title: Text(formatLongDate(_date)),
              subtitle: const Text('Fecha del registro'),
              trailing: const Icon(Icons.edit_calendar_rounded),
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (d != null) setState(() => _date = d);
              },
            ),
          ),
          const SectionTitle('Fotos'),
          Text('Opcionales y privadas: se guardan solo en tu teléfono.',
              style: t.bodySmall?.copyWith(color: FmColors.muted)),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final a in PhotoAngle.values) ...[
                if (a != PhotoAngle.frontal) const SizedBox(width: 10),
                Expanded(
                  child: AspectRatio(
                    aspectRatio: 3 / 4,
                    child: Material(
                      color: FmColors.line,
                      borderRadius: BorderRadius.circular(16),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => _pickPhoto(a),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (_photos[a] != null)
                              ProgressPhoto(photoId: _photos[a]!)
                            else
                              Icon(Icons.add_a_photo_outlined, color: FmColors.primary),
                            Positioned(
                              left: 6,
                              bottom: 6,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(a.label, style: t.labelSmall?.copyWith(color: FmColors.deep)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SectionTitle('Peso y medidas'),
          Text('Rellena solo lo que quieras medir.', style: t.bodySmall?.copyWith(color: FmColors.muted)),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: TextField(
              controller: _height,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Estatura',
                suffixText: 'cm',
                helperText: 'Se guarda una vez y se usa para calcular tu IMC',
              ),
            ),
          ),
          for (final m in measures) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: TextField(
                controller: _ctrl[m],
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: m.label, suffixText: m.unit),
              ),
            ),
            if (m == Measure.peso) ..._bmiLine(t),
          ],
          if (!_showAll)
            TextButton.icon(
              onPressed: () => setState(() => _showAll = true),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Más medidas (muslos, brazos, pecho)'),
            ),
          const SizedBox(height: 8),
          TextField(
            controller: _note,
            maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Nota (opcional)'),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                : const Text('GUARDAR'),
          ),
        ],
      ),
    );
  }
}
