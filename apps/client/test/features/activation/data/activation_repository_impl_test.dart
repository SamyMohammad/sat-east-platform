import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/activation/data/datasources/activation_remote_data_source.dart';
import 'package:sat_east_client/features/activation/data/repositories/activation_repository_impl.dart';
import 'package:sat_east_client/features/activation/domain/entities/activation_result.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/fakes/fake_rpc.dart';
import '../activation_fixtures.dart';

void main() {
  late FakeRpc rpc;
  late ActivationRepositoryImpl repository;

  setUp(() {
    rpc = FakeRpc()..response = activationPayload;
    repository = ActivationRepositoryImpl(ActivationRemoteDataSource(rpc.call));
  });

  test('S-10: repository delegates raw code and test date', () async {
    final result = await repository.redeem(
      ' ab12-cd34 ef56 ',
      DateTime(2027, 3, 15),
    );

    expect(rpc.calls.single.$2, {
      'p_code': ' ab12-cd34 ef56 ',
      'p_target_test_date': '2027-03-15',
    });
    expect((result as Success<ActivationResult>).value.courseId, 'course-1');
  });

  for (final code in [
    ErrorCodes.codeInvalid,
    ErrorCodes.codeUsed,
    ErrorCodes.alreadyEnrolled,
  ]) {
    test('S-10: repository preserves returned $code', () async {
      rpc.response = {'ok': false, 'error': code};

      final result = await repository.redeem('code', DateTime(2027, 3, 15));

      expect((result as Failure).error.code, code);
    });
  }

  for (final code in [
    ErrorCodes.rateLimited,
    ErrorCodes.notAuthenticated,
    ErrorCodes.invalidInput,
  ]) {
    test('S-10: repository preserves raised $code', () async {
      rpc.error = PostgrestException(message: code);

      final result = await repository.redeem('code', DateTime(2027, 3, 15));

      expect((result as Failure).error, AppError(code, code));
    });
  }

  test('S-10: repository preserves transport failure', () async {
    rpc.error = const SocketException('offline');

    final result = await repository.redeem('code', DateTime(2027, 3, 15));

    expect((result as Failure).error.code, ErrorCodes.network);
  });

  test('S-10: repository preserves malformed response failure', () async {
    rpc.response = null;

    final result = await repository.redeem('code', DateTime(2027, 3, 15));

    expect((result as Failure).error.code, ErrorCodes.internal);
  });
}
