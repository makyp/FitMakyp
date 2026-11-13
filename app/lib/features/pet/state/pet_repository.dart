import 'package:flutter/foundation.dart';

import '../../../core/storage/local_store.dart';
import '../domain/pet_items.dart';

/// Nombre de la mascota, objetos comprados, lo que lleva puesto y puntos gastados.
class PetRepository extends ChangeNotifier {
  PetRepository(this._store) {
    final raw = _store.readJson(_key);
    if (raw is Map<String, dynamic>) {
      _name = (raw['name'] as String?) ?? _name;
      _owned = {...List<String>.from((raw['owned'] as List?) ?? const []), defaultColorId};
      _equipped = {
        for (final e in ((raw['equipped'] as Map<String, dynamic>?) ?? const {}).entries)
          if (PetSlot.values.any((s) => s.name == e.key)) PetSlot.values.byName(e.key): e.value as String,
      };
      _spent = (raw['spent'] as int?) ?? 0;
    }
  }

  static const _key = 'pet';
  final LocalStore _store;

  String _name = 'Lila';
  Set<String> _owned = {defaultColorId};
  Map<PetSlot, String> _equipped = {};
  int _spent = 0;

  String get name => _name;
  int get spent => _spent;
  bool owns(String itemId) => _owned.contains(itemId);
  String? equippedIn(PetSlot slot) => _equipped[slot];

  PetLook get look => PetLook(
        head: _equipped[PetSlot.head],
        face: _equipped[PetSlot.face],
        neck: _equipped[PetSlot.neck],
        body: _equipped[PetSlot.body],
        hand: _equipped[PetSlot.hand],
        colorId: _equipped[PetSlot.color] ?? defaultColorId,
      );

  Future<void> rename(String name) async {
    _name = name.trim().isEmpty ? _name : name.trim();
    await _save();
  }

  /// Compra un objeto. [balance] = puntos disponibles, [level] = nivel actual.
  /// Devuelve un mensaje de error o null si se compró.
  Future<String?> buy(PetItem item, {required int balance, required int level}) async {
    if (owns(item.id)) return 'Ya lo tienes.';
    if (level < item.minLevel) return 'Se desbloquea en el nivel ${item.minLevel}.';
    if (balance < item.price) return 'Te faltan ${item.price - balance} puntos.';
    _owned.add(item.id);
    _spent += item.price;
    _equipped[item.slot] = item.id;
    await _save();
    return null;
  }

  /// Regala objetos (premios de retos). No hace nada si ya los tenía.
  Future<void> grant(Iterable<String> ids) async {
    final fresh = ids.where((id) => !_owned.contains(id)).toList();
    if (fresh.isEmpty) return;
    _owned.addAll(fresh);
    await _save();
  }

  Future<void> toggleEquip(PetItem item) async {
    if (!owns(item.id)) return;
    if (_equipped[item.slot] == item.id) {
      _equipped.remove(item.slot);
    } else {
      _equipped[item.slot] = item.id;
    }
    await _save();
  }

  Future<void> _save() async {
    notifyListeners();
    await _store.writeJson(_key, {
      'name': _name,
      'owned': _owned.toList(),
      'equipped': {for (final e in _equipped.entries) e.key.name: e.value},
      'spent': _spent,
    });
  }
}
