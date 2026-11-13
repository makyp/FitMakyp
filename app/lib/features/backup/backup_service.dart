import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';

import '../../app_scope.dart';

/// Copia de seguridad en un archivo .json (datos + fotos). Sin cuentas ni servidores:
/// el archivo lo guardas tú (Drive, WhatsApp, correo…) y lo importas en el teléfono nuevo.
class BackupService {
  BackupService(this.scope);
  final AppScope scope;

  static const _format = 'FitMakyp-backup';
  static const _version = 1;

  Future<Uint8List> buildBackup() async {
    final photoIds = {for (final r in scope.body.records) ...r.photos.values, ...scope.habits.mealPhotoIds};
    final photos = await scope.body.photos.exportAll(photoIds);
    final json = {
      'format': _format,
      'version': _version,
      'createdAt': DateTime.now().toIso8601String(),
      'data': scope.store.exportAll(),
      'photos': {for (final e in photos.entries) e.key: base64Encode(e.value)},
    };
    return Uint8List.fromList(utf8.encode(jsonEncode(json)));
  }

  /// Abre el menú de compartir (en web, descarga el archivo).
  Future<void> exportAndShare() async {
    final bytes = await buildBackup();
    final d = DateTime.now();
    final name = 'fitmakyp_respaldo_${d.year}${_two(d.month)}${_two(d.day)}.json';
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(bytes, name: name, mimeType: 'application/json')],
        fileNameOverrides: [name],
        subject: 'Copia de seguridad de FitMakyp',
      ),
    );
  }

  /// Deja elegir un archivo y lo valida. Devuelve null si se canceló.
  /// Lanza [FormatException] si el archivo no es una copia válida.
  Future<BackupPreview?> pickBackup() async {
    final file = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: ['json']);
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    if (bytes.length > 300 * 1024 * 1024) throw const FormatException('El archivo es demasiado grande.');
    final Object? json;
    try {
      json = jsonDecode(utf8.decode(bytes));
    } catch (_) {
      throw const FormatException('El archivo no es una copia de FitMakyp.');
    }
    if (json is! Map<String, dynamic> || json['format'] != _format || json['data'] is! Map<String, dynamic>) {
      throw const FormatException('El archivo no es una copia de FitMakyp.');
    }
    if ((json['version'] as int? ?? 0) > _version) {
      throw const FormatException('La copia es de una versión más nueva de la app. Actualiza FitMakyp.');
    }
    return BackupPreview(json);
  }

  Future<void> restore(BackupPreview b) async {
    final photos = <String, Uint8List>{
      for (final e in ((b.json['photos'] as Map<String, dynamic>?) ?? const {}).entries)
        if (_safeId(e.key)) e.key: base64Decode(e.value as String),
    };
    await scope.workout.discard();
    await scope.store.replaceAll(b.json['data'] as Map<String, dynamic>);
    await scope.body.photos.importAll(photos);
    await scope.onRestart?.call();
  }

  /// Los ids de foto se usan como nombre de archivo: solo letras, números y _.
  static bool _safeId(String id) => RegExp(r'^[A-Za-z0-9_]{1,64}$').hasMatch(id);

  static String _two(int n) => n.toString().padLeft(2, '0');
}

class BackupPreview {
  BackupPreview(this.json);
  final Map<String, dynamic> json;

  DateTime? get createdAt => DateTime.tryParse(json['createdAt'] as String? ?? '');
  int get workouts => ((json['data'] as Map)['history'] as List?)?.length ?? 0;
  int get records => ((json['data'] as Map)['progressRecords'] as List?)?.length ?? 0;
  int get photos => (json['photos'] as Map?)?.length ?? 0;
}
