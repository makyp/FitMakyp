import 'dart:math';

final _rnd = Random();

/// Identificador único local, ordenable por tiempo.
String newId(String prefix) =>
    '${prefix}_${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${_rnd.nextInt(1 << 20).toRadixString(36)}';
