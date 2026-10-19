import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/auth/data/datasources/device_remote_data_source.dart';
import 'package:sat_east_client/features/auth/domain/entities/my_devices.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/fakes/fake_rpc.dart';

void main() {
  late FakeRpc rpc;
  late DeviceRemoteDataSource source;
  setUp(() {
    rpc = FakeRpc();
    source = DeviceRemoteDataSource(rpc.call);
  });

  test(
    'AUTH-04: lists own devices with current marker and creation date',
    () async {
      rpc.response = {
        'changes_left': 1,
        'devices': [
          {
            'id': 'd1',
            'platform': 'web',
            'label': 'Laptop',
            'last_seen_at': '2026-10-18T00:00:00Z',
            'created_at': '2026-10-01T00:00:00Z',
            'is_current': true,
          },
          {
            'id': 'd2',
            'platform': null,
            'label': null,
            'last_seen_at': null,
            'created_at': '2026-10-02T00:00:00Z',
            'is_current': false,
          },
        ],
      };
      final devices =
          (await source.listMine(fingerprint: 'current-fingerprint')
                  as Success<MyDevices>)
              .value;
      expect(rpc.calls.single.$1, 'list_my_devices');
      expect(
        rpc.calls.single.$2,
        equals({'p_fingerprint': 'current-fingerprint'}),
      );
      expect(devices.changesLeft, 1);
      expect(devices.devices.map((d) => d.id), ['d1', 'd2']);
      expect(devices.devices.first.isCurrent, isTrue);
      expect(devices.devices.first.createdAt, DateTime.utc(2026, 10));
      expect(devices.devices.first.lastSeenAt, DateTime.utc(2026, 10, 18));
      expect(devices.devices.last.isCurrent, isFalse);
      expect(devices.devices.last.lastSeenAt, isNull);
      expect(devices.devices.last.label, isNull);
    },
  );

  test('AUTH-04: lists an empty device collection', () async {
    rpc.response = {'changes_left': 2, 'devices': <Object?>[]};
    final result =
        (await source.listMine(fingerprint: 'fp') as Success<MyDevices>).value;
    expect(result.devices, isEmpty);
    expect(result.changesLeft, 2);
  });

  final malformed = <Object?>[
    null,
    'wrong',
    {'devices': <Object?>[]},
    {'changes_left': -1, 'devices': <Object?>[]},
    {'changes_left': '2', 'devices': <Object?>[]},
    {'changes_left': 2, 'devices': 'wrong'},
    {
      'changes_left': 2,
      'devices': [null],
    },
    for (final device in <Object?>[
      {'is_current': true, 'created_at': '2026-10-01T00:00:00Z'},
      {'id': 'd1', 'is_current': 'yes', 'created_at': '2026-10-01T00:00:00Z'},
      {'id': 'd1', 'created_at': '2026-10-01T00:00:00Z'},
      {'id': 'd1', 'is_current': false},
      {'id': 'd1', 'is_current': false, 'created_at': 'bad-date'},
      {'id': 'd1', 'is_current': false, 'created_at': 4},
    ])
      {
        'changes_left': 2,
        'devices': [device],
      },
  ];
  for (var i = 0; i < malformed.length; i++) {
    test('AUTH-04: malformed listing $i returns internal', () async {
      rpc.response = malformed[i];
      expect(
        (await source.listMine(fingerprint: 'fp') as Failure<MyDevices>)
            .error
            .code,
        ErrorCodes.internal,
      );
    });
  }

  for (final code in [
    ErrorCodes.notAuthenticated,
    ErrorCodes.invalidInput,
    ErrorCodes.internal,
  ]) {
    test('AUTH-04: list maps server error $code', () async {
      rpc.error = PostgrestException(message: code);
      expect(
        (await source.listMine(fingerprint: 'fp') as Failure<MyDevices>)
            .error
            .code,
        code,
      );
    });
  }
  for (final failure in <(Object, String)>[
    (const SocketException('offline'), ErrorCodes.network),
    (StateError('unexpected'), ErrorCodes.internal),
  ]) {
    test('AUTH-04: list maps transport ${failure.$2}', () async {
      rpc.error = failure.$1;
      expect(
        (await source.listMine(fingerprint: 'fp') as Failure<MyDevices>)
            .error
            .code,
        failure.$2,
      );
    });
  }
}
