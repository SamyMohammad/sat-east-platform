import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/auth/data/datasources/device_remote_data_source.dart';
import 'package:sat_east_client/features/auth/data/models/device_model.dart';
import 'package:sat_east_client/features/auth/domain/entities/device.dart';
import 'package:sat_east_client/features/auth/domain/entities/device_registration.dart';
import 'package:sat_east_client/features/auth/domain/entities/device_status.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'fakes.dart';

void main() {
  late FakeRpc rpc;
  late DeviceRemoteDataSource source;

  setUp(() {
    rpc = FakeRpc();
    source = DeviceRemoteDataSource(rpc.call);
  });

  group('P1-2: DeviceModel.fromJson', () {
    test('P1-2: parses an ISO last_seen_at', () {
      final Device model = DeviceModel.fromJson(const {
        'id': 'd1',
        'platform': 'web',
        'label': 'Chrome on Windows',
        'last_seen_at': '2026-10-01T12:30:00+00:00',
      });

      expect(model.id, 'd1');
      expect(model.platform, 'web');
      expect(model.label, 'Chrome on Windows');
      expect(model.lastSeenAt, DateTime.utc(2026, 10, 1, 12, 30));
    });

    test('P1-2: keeps null last_seen_at, platform and label', () {
      final Device model = DeviceModel.fromJson(const {
        'id': 'd2',
        'platform': null,
        'label': null,
        'last_seen_at': null,
      });

      expect(model.lastSeenAt, isNull);
      expect(model.platform, isNull);
      expect(model.label, isNull);
    });
  });

  group('P1-2: register', () {
    test('P1-2: calls register_device with the exact param keys', () async {
      rpc.response = {'status': 'ok', 'device_id': 'd1'};

      await source.register(
        fingerprint: 'fp-0123456789abcdef',
        platform: 'web',
        label: 'Chrome on Windows',
      );

      expect(rpc.calls, hasLength(1));
      expect(rpc.calls.single.$1, 'register_device');
      expect(rpc.calls.single.$2, {
        'p_fingerprint': 'fp-0123456789abcdef',
        'p_platform': 'web',
        'p_label': 'Chrome on Windows',
      });
    });

    test('P1-2: maps status ok to DeviceAllowed', () async {
      rpc.response = {'status': 'ok', 'device_id': 'd1'};

      final result = await source.register(
        fingerprint: 'fp',
        platform: 'web',
        label: 'x',
      );

      expect(
        (result as Success<DeviceRegistration>).value,
        const DeviceAllowed('d1'),
      );
    });

    test('P1-2: maps limit_reached to devices and changesLeft', () async {
      rpc.response = {
        'status': 'limit_reached',
        'changes_left': 2,
        'devices': [
          {
            'id': 'd1',
            'platform': 'web',
            'label': 'Chrome on Windows',
            'last_seen_at': '2026-10-01T12:30:00+00:00',
          },
          {
            'id': 'd2',
            'platform': 'android',
            'label': 'Android app',
            'last_seen_at': null,
          },
        ],
      };

      final result = await source.register(
        fingerprint: 'fp',
        platform: 'web',
        label: 'x',
      );

      final value = (result as Success<DeviceRegistration>).value;
      expect(value, isA<DeviceLimitReached>());
      final limit = value as DeviceLimitReached;
      expect(limit.changesLeft, 2);
      expect(limit.devices.map((d) => d.id), ['d1', 'd2']);
      expect(limit.devices[0].lastSeenAt, DateTime.utc(2026, 10, 1, 12, 30));
      expect(limit.devices[1].lastSeenAt, isNull);
      expect(limit.devices[1].platform, 'android');
    });

    test(
      'P1-2: limit_reached equals a hand-built DeviceLimitReached',
      () async {
        rpc.response = {
          'status': 'limit_reached',
          'changes_left': 2,
          'devices': [
            {
              'id': 'd1',
              'platform': 'web',
              'label': 'Chrome on Windows',
              'last_seen_at': '2026-10-01T12:30:00+00:00',
            },
            {
              'id': 'd2',
              'platform': 'android',
              'label': 'Android app',
              'last_seen_at': null,
            },
          ],
        };

        final result = await source.register(
          fingerprint: 'fp',
          platform: 'web',
          label: 'x',
        );

        expect(
          (result as Success<DeviceRegistration>).value,
          DeviceLimitReached(
            devices: [
              Device(
                id: 'd1',
                platform: 'web',
                label: 'Chrome on Windows',
                lastSeenAt: DateTime.utc(2026, 10, 1, 12, 30),
              ),
              const Device(id: 'd2', platform: 'android', label: 'Android app'),
            ],
            changesLeft: 2,
          ),
        );
      },
    );

    test('P1-2: maps limit_reached with no devices to an empty list', () async {
      rpc.response = {
        'status': 'limit_reached',
        'changes_left': 0,
        'devices': <Object?>[],
      };

      final result = await source.register(
        fingerprint: 'fp',
        platform: 'web',
        label: 'x',
      );

      final limit =
          (result as Success<DeviceRegistration>).value as DeviceLimitReached;
      expect(limit.devices, isEmpty);
      expect(limit.changesLeft, 0);
    });

    final malformed = <String, Object?>{
      'null payload': null,
      'a string payload': 'ok',
      'unknown status': {'status': 'weird'},
      'ok without device_id': {'status': 'ok'},
      'limit_reached without changes_left': {
        'status': 'limit_reached',
        'devices': <Object?>[],
      },
      'limit_reached with bad device': {
        'status': 'limit_reached',
        'changes_left': 1,
        'devices': [
          {'platform': 'web'},
        ],
      },
    };
    for (final entry in malformed.entries) {
      test('P1-2: maps ${entry.key} to internal', () async {
        rpc.response = entry.value;

        final result = await source.register(
          fingerprint: 'fp',
          platform: 'web',
          label: 'x',
        );

        expect(
          (result as Failure<DeviceRegistration>).error.code,
          ErrorCodes.internal,
        );
      });
    }

    const errors = [ErrorCodes.notAuthenticated, ErrorCodes.invalidInput];
    for (final code in errors) {
      test('P1-2: maps PostgrestException $code', () async {
        rpc.error = PostgrestException(message: code);

        final result = await source.register(
          fingerprint: 'fp',
          platform: 'web',
          label: 'x',
        );

        expect((result as Failure<DeviceRegistration>).error.code, code);
      });
    }
  });

  group('P1-2: status', () {
    test('P1-2: calls device_status with p_fingerprint', () async {
      rpc.response = 'active';

      await source.status(fingerprint: 'fp-0123456789abcdef');

      expect(rpc.calls.single.$1, 'device_status');
      expect(rpc.calls.single.$2, {'p_fingerprint': 'fp-0123456789abcdef'});
    });

    const cases = {
      'active': DeviceStatus.active,
      'revoked': DeviceStatus.revoked,
      'unknown': DeviceStatus.unknown,
    };
    for (final entry in cases.entries) {
      test('P1-2: maps "${entry.key}" to ${entry.value}', () async {
        rpc.response = entry.key;

        final result = await source.status(fingerprint: 'fp');

        expect((result as Success<DeviceStatus>).value, entry.value);
      });
    }

    test('P1-2: maps an unexpected status string to internal', () async {
      rpc.response = 'banana';

      final result = await source.status(fingerprint: 'fp');

      expect((result as Failure<DeviceStatus>).error.code, ErrorCodes.internal);
    });

    test('P1-2: maps a non-string payload to internal', () async {
      rpc.response = 42;

      final result = await source.status(fingerprint: 'fp');

      expect((result as Failure<DeviceStatus>).error.code, ErrorCodes.internal);
    });

    test('P1-2: maps not_authenticated', () async {
      rpc.error = const PostgrestException(message: 'not_authenticated');

      final result = await source.status(fingerprint: 'fp');

      expect(
        (result as Failure<DeviceStatus>).error.code,
        ErrorCodes.notAuthenticated,
      );
    });
  });

  group('P1-2: remove', () {
    test('P1-2: calls remove_device with p_device_id', () async {
      rpc.response = {'changes_left': 1};

      await source.remove('d1');

      expect(rpc.calls.single.$1, 'remove_device');
      expect(rpc.calls.single.$2, {'p_device_id': 'd1'});
    });

    test('P1-2: returns changes_left', () async {
      rpc.response = {'changes_left': 1};

      final result = await source.remove('d1');

      expect((result as Success<int>).value, 1);
    });

    test('P1-2: maps a payload without changes_left to internal', () async {
      rpc.response = <String, Object?>{};

      final result = await source.remove('d1');

      expect((result as Failure<int>).error.code, ErrorCodes.internal);
    });

    const errors = [
      ErrorCodes.deviceLimit,
      ErrorCodes.forbidden,
      ErrorCodes.notAuthenticated,
    ];
    for (final code in errors) {
      test('P1-2: maps PostgrestException $code', () async {
        rpc.error = PostgrestException(message: code);

        final result = await source.remove('d1');

        expect((result as Failure<int>).error.code, code);
      });
    }

    test('P1-2: maps a transport error to network', () async {
      rpc.error = const SocketException('offline');

      final result = await source.remove('d1');

      expect((result as Failure<int>).error.code, ErrorCodes.network);
    });
  });
}
