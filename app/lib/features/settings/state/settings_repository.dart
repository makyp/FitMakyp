import 'package:flutter/foundation.dart';

import '../../../core/models/settings.dart';
import '../../../core/storage/local_store.dart';

class SettingsRepository extends ChangeNotifier {
  SettingsRepository(this._store) {
    final raw = _store.readJson(_key);
    if (raw is Map<String, dynamic>) _settings = AppSettings.fromJson(raw);
  }

  static const _key = 'settings';
  final LocalStore _store;
  AppSettings _settings = const AppSettings();

  AppSettings get settings => _settings;

  Future<void> update(AppSettings value) async {
    _settings = value;
    notifyListeners();
    await _store.writeJson(_key, value.toJson());
  }
}
