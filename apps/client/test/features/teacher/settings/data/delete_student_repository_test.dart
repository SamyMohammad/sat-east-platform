import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/teacher/settings/data/datasources/teacher_settings_remote_data_source.dart';
import 'package:sat_east_client/features/teacher/settings/data/repositories/teacher_settings_repository_impl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/fakes/fake_rpc.dart';

void main() {
  late FakeRpc rpc;
  late TeacherSettingsRepositoryImpl repo;
  setUp(() {
    rpc = FakeRpc();
    repo = TeacherSettingsRepositoryImpl(
      TeacherSettingsRemoteDataSource(rpc.call),
    );
  });
  test('P3: deleteStudent calls admin_delete_student with p_email', () async {
    rpc.response = {
      'ok': true,
      'deleted_user_id': 'u1',
      'counts': {'attempts': 2},
    };
    expect(await repo.deleteStudent('a@b.com'), isA<Success<void>>());
    expect(rpc.calls.single.$1, 'admin_delete_student');
    expect(rpc.calls.single.$2, equals({'p_email': 'a@b.com'}));
  });
  for (final code in [
    ErrorCodes.notAuthenticated,
    ErrorCodes.forbidden,
    ErrorCodes.invalidInput,
    ErrorCodes.studentNotFound,
    ErrorCodes.studentHasOrders,
    ErrorCodes.rateLimited,
  ]) {
    test('P3: deleteStudent maps $code', () async {
      rpc.error = PostgrestException(message: code);
      final result = await repo.deleteStudent('a@b.com');
      expect((result as Failure).error.code, code);
    });
  }
  test('P3: deleteStudent maps network errors', () async {
    rpc.error = const SocketException('offline');
    final result = await repo.deleteStudent('a@b.com');
    expect((result as Failure).error.code, ErrorCodes.network);
  });
  test('P3: deleteStudent maps unknown server text to internal', () async {
    rpc.error = const PostgrestException(message: 'boom');
    final result = await repo.deleteStudent('a@b.com');
    expect((result as Failure).error.code, ErrorCodes.internal);
  });
  test('P3: deleteStudent rejects a malformed payload', () async {
    rpc.response = {'ok': false};
    final result = await repo.deleteStudent('a@b.com');
    expect((result as Failure).error.code, ErrorCodes.internal);
  });
}
