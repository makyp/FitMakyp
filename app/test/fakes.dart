import 'dart:typed_data';

import 'package:fitmakyp/core/storage/photo_store.dart';

/// Fotos en memoria para las pruebas.
class MemoryPhotoStore implements PhotoStore {
  final _m = <String, Uint8List>{};
  var _n = 0;

  @override
  Future<String> save(Uint8List bytes) async {
    final id = 'p${_n++}';
    _m[id] = bytes;
    return id;
  }

  @override
  Future<Uint8List?> load(String id) async => _m[id];

  @override
  Future<void> delete(String id) async => _m.remove(id);

  @override
  Future<Map<String, Uint8List>> exportAll(Iterable<String> ids) async => {for (final id in ids) if (_m[id] != null) id: _m[id]!};

  @override
  Future<void> importAll(Map<String, Uint8List> photos) async => _m.addAll(photos);
}
