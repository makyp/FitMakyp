import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Almacenamiento local en el dispositivo (Android, iOS y web).
///
/// Es la única clase que conoce SharedPreferences: si más adelante se pasa a
/// una base de datos local o a un backend, solo cambia esta capa.
class LocalStore {
  LocalStore(this._prefs);

  static const _prefix = 'fm.v1.';

  final SharedPreferences _prefs;

  static Future<LocalStore> open() async => LocalStore(await SharedPreferences.getInstance());

  /// Devuelve null si no existe o si el dato está corrupto (no rompe la app).
  Object? readJson(String key) {
    final raw = _prefs.getString('$_prefix$key');
    if (raw == null) return null;
    try {
      return jsonDecode(raw);
    } catch (e) {
      debugPrint('LocalStore: dato ilegible en "$key": $e');
      return null;
    }
  }

  /// Todos los datos de la app (para la copia de seguridad). Excluye las fotos guardadas en web.
  Map<String, Object?> exportAll() => {
        for (final k in _prefs.getKeys())
          if (k.startsWith(_prefix) && !k.startsWith('${_prefix}photo.')) k.substring(_prefix.length): readJson(k.substring(_prefix.length)),
      };

  /// Sustituye todos los datos por los de una copia de seguridad.
  Future<void> replaceAll(Map<String, Object?> data) async {
    for (final k in _prefs.getKeys().where((k) => k.startsWith(_prefix) && !k.startsWith('${_prefix}photo.')).toList()) {
      await _prefs.remove(k);
    }
    for (final e in data.entries) {
      await writeJson(e.key, e.value);
    }
  }

  Future<void> writeJson(String key, Object? value) async {
    if (value == null) {
      await _prefs.remove('$_prefix$key');
    } else {
      await _prefs.setString('$_prefix$key', jsonEncode(value));
    }
  }
}
