import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:sat_east_client/features/auth/data/datasources/device_remote_data_source.dart';
import 'package:sat_east_client/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:sat_east_client/features/auth/data/repositories/device_repository_impl.dart';
import 'package:sat_east_client/features/auth/domain/entities/my_devices.dart';
import 'package:sat_east_client/features/auth/domain/entities/my_profile.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/fakes/fake_rpc.dart';
import 'fakes.dart';

class _MockAuthRemote extends Mock implements AuthRemoteDataSource {}

void main() {
  group('AUTH-06: account auth repository', () {
    late _MockAuthRemote remote;
    late AuthRepositoryImpl repository;
    setUp(() {
      remote = _MockAuthRemote();
      repository = AuthRepositoryImpl(remote);
    });

    for (final code in <String?>[
      null,
      ErrorCodes.rateLimited,
      ErrorCodes.network,
      ErrorCodes.internal,
    ]) {
      test('AUTH-06: reset returns ${code ?? 'success'}', () async {
        final expected = code == null
            ? const Success<void>(null)
            : Failure<void>(AppError(code));
        when(
          () => remote.requestPasswordReset('student@example.com'),
        ).thenAnswer((_) async => expected);
        expect(
          await repository.requestPasswordReset('student@example.com'),
          same(expected),
        );
      });
    }
    for (final code in <String?>[
      null,
      ErrorCodes.weakPassword,
      ErrorCodes.rateLimited,
      ErrorCodes.network,
      ErrorCodes.notAuthenticated,
      ErrorCodes.internal,
    ]) {
      test('AUTH-06: password update returns ${code ?? 'success'}', () async {
        final expected = code == null
            ? const Success<void>(null)
            : Failure<void>(AppError(code));
        when(
          () => remote.updatePassword('new-password'),
        ).thenAnswer((_) async => expected);
        expect(await repository.updatePassword('new-password'), same(expected));
      });
    }
    for (final code in <String?>[
      null,
      ErrorCodes.notAuthenticated,
      ErrorCodes.forbidden,
      ErrorCodes.network,
      ErrorCodes.internal,
    ]) {
      test('S-34: profile returns ${code ?? 'success'}', () async {
        final expected = code == null
            ? const Success<MyProfile>(
                MyProfile(
                  fullName: 'Student Name',
                  email: 'student@example.com',
                ),
              )
            : Failure<MyProfile>(AppError(code));
        when(() => remote.getMyProfile()).thenAnswer((_) async => expected);
        expect(await repository.getMyProfile(), same(expected));
      });
    }

    test('AUTH-06: repository exposes recovery events', () async {
      when(
        () => remote.passwordRecovery,
      ).thenAnswer((_) => Stream<void>.value(null));
      expect(await repository.passwordRecovery.toList(), hasLength(1));
    });
  });

  group('AUTH-04: account device repository', () {
    late FakeRpc rpc;
    late DeviceRepositoryImpl repository;
    setUp(() {
      rpc = FakeRpc();
      repository = DeviceRepositoryImpl(
        idStore: FakeDeviceIdStore('stored-fingerprint'),
        info: FakeDeviceInfo(),
        remote: DeviceRemoteDataSource(rpc.call),
      );
    });

    test('AUTH-04: listMine uses the persisted fingerprint', () async {
      rpc.response = {'changes_left': 2, 'devices': <Object?>[]};
      final result = (await repository.listMine() as Success<MyDevices>).value;
      expect(result.changesLeft, 2);
      expect(result.devices, isEmpty);
      expect(rpc.calls.single.$1, 'list_my_devices');
      expect(
        rpc.calls.single.$2,
        equals({'p_fingerprint': 'stored-fingerprint'}),
      );
    });

    for (final code in [
      ErrorCodes.notAuthenticated,
      ErrorCodes.invalidInput,
      ErrorCodes.internal,
    ]) {
      test('AUTH-04: listMine passes $code through', () async {
        rpc.error = PostgrestException(message: code);
        expect(
          (await repository.listMine() as Failure<MyDevices>).error.code,
          code,
        );
      });
    }

    test('AUTH-04: listMine passes network failures through', () async {
      rpc.error = const SocketException('offline');
      expect(
        (await repository.listMine() as Failure<MyDevices>).error.code,
        ErrorCodes.network,
      );
    });

    test('AUTH-04: listMine maps malformed payload to internal', () async {
      rpc.response = {'devices': <Object?>[]};
      expect(
        (await repository.listMine() as Failure<MyDevices>).error.code,
        ErrorCodes.internal,
      );
    });

    for (final failure in <(Object, String)>[
      (StateError('disk'), ErrorCodes.internal),
      (TimeoutException('disk'), ErrorCodes.network),
    ]) {
      test('AUTH-04: listMine maps id store failure ${failure.$2}', () async {
        repository = DeviceRepositoryImpl(
          idStore: FakeDeviceIdStore('unused', error: failure.$1),
          info: FakeDeviceInfo(),
          remote: DeviceRemoteDataSource(rpc.call),
        );
        expect(
          (await repository.listMine() as Failure<MyDevices>).error.code,
          failure.$2,
        );
        expect(rpc.calls, isEmpty);
      });
    }
  });
}
