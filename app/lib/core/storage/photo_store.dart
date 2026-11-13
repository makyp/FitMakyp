import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../utils/ids.dart';
import 'local_store.dart';

/// Fotos de progreso. Son privadas: se guardan solo en el dispositivo, nunca se suben.
abstract class PhotoStore {
  Future<String> save(Uint8List bytes);
  Future<Uint8List?> load(String id);
  Future<void> delete(String id);

  /// Todas las fotos (para la copia de seguridad).
  Future<Map<String, Uint8List>> exportAll(Iterable<String> ids);
  Future<void> importAll(Map<String, Uint8List> photos);

  static Future<PhotoStore> create(LocalStore store) async {
    if (kIsWeb) return _PrefsPhotoStore(store);
    final dir = Directory('${(await getApplicationDocumentsDirectory()).path}/progress_photos');
    await dir.create(recursive: true);
    return _FilePhotoStore(dir);
  }
}

/// Android / iOS: archivos en la carpeta privada de la app.
class _FilePhotoStore implements PhotoStore {
  _FilePhotoStore(this._dir);
  final Directory _dir;
  final _cache = <String, Uint8List>{};

  File _file(String id) => File('${_dir.path}/$id.jpg');

  @override
  Future<String> save(Uint8List bytes) async {
    final id = newId('photo');
    await _file(id).writeAsBytes(bytes, flush: true);
    _cache[id] = bytes;
    return id;
  }

  @override
  Future<Uint8List?> load(String id) async {
    final cached = _cache[id];
    if (cached != null) return cached;
    final f = _file(id);
    if (!await f.exists()) return null;
    return _cache[id] = await f.readAsBytes();
  }

  @override
  Future<void> delete(String id) async {
    _cache.remove(id);
    final f = _file(id);
    if (await f.exists()) await f.delete();
  }

  @override
  Future<Map<String, Uint8List>> exportAll(Iterable<String> ids) async => {
        for (final id in ids) id: ?await load(id),
      };

  @override
  Future<void> importAll(Map<String, Uint8List> photos) async {
    for (final e in photos.entries) {
      await _file(e.key).writeAsBytes(e.value, flush: true);
      _cache[e.key] = e.value;
    }
  }
}

/// Web (demo): fotos comprimidas dentro del almacenamiento del navegador. Espacio limitado.
class _PrefsPhotoStore implements PhotoStore {
  _PrefsPhotoStore(this._store);
  final LocalStore _store;

  String _key(String id) => 'photo.$id';

  @override
  Future<String> save(Uint8List bytes) async {
    final id = newId('photo');
    await _store.writeJson(_key(id), base64Encode(bytes));
    return id;
  }

  @override
  Future<Uint8List?> load(String id) async {
    final raw = _store.readJson(_key(id));
    return raw is String ? base64Decode(raw) : null;
  }

  @override
  Future<void> delete(String id) => _store.writeJson(_key(id), null);

  @override
  Future<Map<String, Uint8List>> exportAll(Iterable<String> ids) async => {
        for (final id in ids) id: ?await load(id),
      };

  @override
  Future<void> importAll(Map<String, Uint8List> photos) async {
    for (final e in photos.entries) {
      await _store.writeJson(_key(e.key), base64Encode(e.value));
    }
  }
}
