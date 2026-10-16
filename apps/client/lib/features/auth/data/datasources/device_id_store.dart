import 'dart:math';

import 'package:hive_ce/hive.dart';

/// Persists a random per-install device id (32 lowercase hex chars).
class DeviceIdStore {
  DeviceIdStore(this._box);

  static const _key = 'id';

  final Box<String> _box;

  Future<String> read() async {
    final existing = _box.get(_key);
    if (existing != null) return existing;
    final random = Random.secure();
    final id = List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    await _box.put(_key, id);
    return id;
  }
}
