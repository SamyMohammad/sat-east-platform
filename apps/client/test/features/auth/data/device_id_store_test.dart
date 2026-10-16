import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:sat_east_client/features/auth/data/datasources/device_id_store.dart';

void main() {
  late Directory dir;
  late Box<String> box;
  var counter = 0;

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('device_id_store_');
    Hive.init(dir.path);
    box = await Hive.openBox<String>(
      'device_test_${DateTime.now().microsecondsSinceEpoch}_${counter++}',
    );
  });

  tearDown(() async {
    await Hive.close();
    dir.deleteSync(recursive: true);
  });

  test('P1-2: generates a 32 char lowercase hex id', () async {
    final id = await DeviceIdStore(box).read();
    expect(id, matches(RegExp(r'^[0-9a-f]{32}$')));
  });

  test('P1-2: returns the same id on repeated reads', () async {
    final store = DeviceIdStore(box);
    final first = await store.read();
    expect(await store.read(), first);
  });

  test('P1-2: a new store over the same box reads the persisted id', () async {
    final first = await DeviceIdStore(box).read();
    expect(await DeviceIdStore(box).read(), first);
  });

  test('P1-2: concurrent reads on an empty box return one id', () async {
    final store = DeviceIdStore(box);
    final ids = await Future.wait([store.read(), store.read()]);
    expect(ids[0], ids[1]);
    expect(box.get('id'), ids[0]);
  });

  test('P1-2: replaces a corrupt stored value with a new valid id', () async {
    await box.put('id', 'not-a-valid-id');
    final id = await DeviceIdStore(box).read();
    expect(id, matches(RegExp(r'^[0-9a-f]{32}$')));
    expect(box.get('id'), id);
  });

  test('P1-2: ids differ across separate boxes', () async {
    final other = await Hive.openBox<String>(
      'device_test_other_${DateTime.now().microsecondsSinceEpoch}',
    );
    final a = await DeviceIdStore(box).read();
    final b = await DeviceIdStore(other).read();
    expect(a, isNot(b));
  });
}
