import 'dart:math';

import 'package:hive_ce/hive.dart';

/// Persists a random per-install device id (32 lowercase hex chars).
class DeviceIdStore {
  DeviceIdStore(this._box);

  static const _key = 'id';

  static final _validId = RegExp(r'^[0-9a-f]{32}$');

  final Box<String> _box;
  Future<String>? _pending;

  Future<String> read() {
    final existing = _box.get(_key);
    if (existing != null && _validId.hasMatch(existing)) {
      return Future.value(existing);
    }
    // Concurrent first reads share one generation.
    return _pending ??= _generate().whenComplete(() => _pending = null);
  }

  Future<String> _generate() async {
    final random = Random.secure();
    final id = List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    await _box.put(_key, id);
    return id;
  }
}
