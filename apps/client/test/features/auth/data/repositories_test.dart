import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:sat_east_client/features/auth/data/datasources/device_remote_data_source.dart';
import 'package:sat_east_client/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:sat_east_client/features/auth/data/repositories/device_repository_impl.dart';
import 'package:sat_east_client/features/auth/domain/entities/app_user.dart';
import 'package:sat_east_client/features/auth/domain/entities/device_registration.dart';
import 'package:sat_east_client/features/auth/domain/entities/device_status.dart';
import 'package:sat_east_client/features/auth/domain/entities/sign_up_outcome.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../../core/fakes/fake_rpc.dart';
import 'fakes.dart';

class MockAuthRemoteDataSource extends Mock implements AuthRemoteDataSource {}

void main() {
  group('P1-2: AuthRepositoryImpl', () {
    late MockAuthRemoteDataSource remote;
    late AuthRepositoryImpl repository;
    const user = AppUser(id: 'u1', email: 'a@b.co');

    setUp(() {
      remote = MockAuthRemoteDataSource();
      repository = AuthRepositoryImpl(remote);
    });

    test('P1-2: signIn delegates to the data source', () async {
      when(
        () => remote.signIn(email: 'a@b.co', password: 'pw'),
      ).thenAnswer((_) async => const Success(user));

      final result = await repository.signIn(email: 'a@b.co', password: 'pw');

      expect((result as Success<AppUser>).value, user);
    });

    test('P1-2: signUp delegates to the data source', () async {
      when(
        () => remote.signUp(
          email: 'a@b.co',
          password: 'pw',
          fullName: 'Sam Ali',
        ),
      ).thenAnswer((_) async => const Success(SignUpOutcome.confirmationSent));

      final result = await repository.signUp(
        email: 'a@b.co',
        password: 'pw',
        fullName: 'Sam Ali',
      );

      expect(
        (result as Success<SignUpOutcome>).value,
        SignUpOutcome.confirmationSent,
      );
    });

    test('P1-2: signOut delegates to the data source', () async {
      when(() => remote.signOut()).thenAnswer((_) async => const Success(null));

      expect(await repository.signOut(), isA<Success<void>>());
    });

    test('P1-2: currentUser reads from the data source', () {
      when(() => remote.currentUser).thenReturn(user);

      expect(repository.currentUser, user);
    });

    test('P1-2: userChanges forwards the data source stream', () {
      when(() => remote.userChanges).thenAnswer((_) => Stream.value(user));

      expect(repository.userChanges, emits(user));
    });
  });

  group('P1-2: DeviceRepositoryImpl', () {
    const fingerprint = '0123456789abcdef0123456789abcdef';
    late FakeRpc rpc;
    late DeviceRepositoryImpl repository;

    setUp(() {
      rpc = FakeRpc();
      repository = DeviceRepositoryImpl(
        idStore: FakeDeviceIdStore(fingerprint),
        info: FakeDeviceInfo(),
        remote: DeviceRemoteDataSource(rpc.call),
      );
    });

    test('P1-2: register passes fingerprint, platform and label', () async {
      rpc.response = {'status': 'ok', 'device_id': 'd1'};

      final result = await repository.register();

      expect(rpc.calls.single.$1, 'register_device');
      expect(rpc.calls.single.$2, {
        'p_fingerprint': fingerprint,
        'p_platform': 'android',
        'p_label': 'Android app',
      });
      expect(
        (result as Success<DeviceRegistration>).value,
        const DeviceAllowed('d1'),
      );
    });

    test('P1-2: register returns internal when the id store throws', () async {
      repository = DeviceRepositoryImpl(
        idStore: FakeDeviceIdStore(fingerprint, error: StateError('disk')),
        info: FakeDeviceInfo(),
        remote: DeviceRemoteDataSource(rpc.call),
      );

      final result = await repository.register();

      expect(
        (result as Failure<DeviceRegistration>).error.code,
        ErrorCodes.internal,
      );
      expect(rpc.calls, isEmpty);
    });

    test('P1-2: status returns internal when the id store throws', () async {
      repository = DeviceRepositoryImpl(
        idStore: FakeDeviceIdStore(fingerprint, error: StateError('disk')),
        info: FakeDeviceInfo(),
        remote: DeviceRemoteDataSource(rpc.call),
      );

      final result = await repository.status();

      expect(
        (result as Failure<DeviceStatus>).error.code,
        ErrorCodes.internal,
      );
    });

    test('P1-2: remove passes a data source failure through', () async {
      rpc.error = const PostgrestException(message: 'device_limit');

      final result = await repository.remove('d9');

      expect((result as Failure<int>).error.code, ErrorCodes.deviceLimit);
    });

    test('P1-2: status passes the stored fingerprint', () async {
      rpc.response = 'revoked';

      final result = await repository.status();

      expect(rpc.calls.single.$1, 'device_status');
      expect(rpc.calls.single.$2, {'p_fingerprint': fingerprint});
      expect((result as Success<DeviceStatus>).value, DeviceStatus.revoked);
    });

    test('P1-2: remove passes the device id and returns changes', () async {
      rpc.response = {'changes_left': 3};

      final result = await repository.remove('d9');

      expect(rpc.calls.single.$1, 'remove_device');
      expect(rpc.calls.single.$2, {'p_device_id': 'd9'});
      expect((result as Success<int>).value, 3);
    });
  });
}
