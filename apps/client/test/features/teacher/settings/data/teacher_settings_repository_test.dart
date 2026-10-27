import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/teacher/settings/data/datasources/teacher_settings_remote_data_source.dart';
import 'package:sat_east_client/features/teacher/settings/data/repositories/teacher_settings_repository_impl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/fakes/fake_rpc.dart';
import '../settings_fixtures.dart';

void main() {
  late FakeRpc rpc;
  late TeacherSettingsRepositoryImpl repo;
  setUp(() {
    rpc = FakeRpc();
    repo = TeacherSettingsRepositoryImpl(
      TeacherSettingsRemoteDataSource(rpc.call),
    );
  });
  test('ADM-06: load uses teacher_get_settings and parses specs', () async {
    rpc.response = settingsJson;
    expect((await repo.load() as Success).value, settingsSpecs);
    expect(rpc.calls.single.$1, 'teacher_get_settings');
    expect(rpc.calls.single.$2, isEmpty);
  });
  test('ADM-06: save sends only supplied keys as p_values', () async {
    rpc.response = {
      'ok': true,
      'updated': ['pass_mark'],
    };
    expect(await repo.save({'pass_mark': 80}), isA<Success<void>>());
    expect(rpc.calls.single.$1, 'teacher_update_settings');
    expect(
      rpc.calls.single.$2,
      equals({
        'p_values': {'pass_mark': 80},
      }),
    );
  });
  for (final save in [false, true]) {
    for (final code in [
      ErrorCodes.invalidInput,
      ErrorCodes.forbidden,
      ErrorCodes.notAuthenticated,
      ErrorCodes.rateLimited,
    ]) {
      test('ADM-06: ${save ? 'save' : 'load'} maps $code', () async {
        rpc.error = PostgrestException(message: code);
        final result = save
            ? await repo.save({'pass_mark': 80})
            : await repo.load();
        expect((result as Failure).error.code, code);
      });
    }
    test('ADM-06: ${save ? 'save' : 'load'} maps network errors', () async {
      rpc.error = const SocketException('offline');
      final result = save
          ? await repo.save({'pass_mark': 80})
          : await repo.load();
      expect((result as Failure).error.code, ErrorCodes.network);
    });
    for (final raw in <Object?>[
      null,
      {'ok': false},
      'bad',
      {
        'ok': true,
        'updated': [12],
      },
    ]) {
      test(
        'ADM-06: ${save ? 'save' : 'load'} rejects malformed payload $raw',
        () async {
          rpc.response = raw;
          final result = save
              ? await repo.save({'pass_mark': 80})
              : await repo.load();
          expect((result as Failure).error.code, ErrorCodes.internal);
        },
      );
    }
  }
}
