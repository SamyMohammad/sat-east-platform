import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/activation/data/datasources/activation_remote_data_source.dart';
import 'package:sat_east_client/features/activation/domain/entities/activation_result.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/fakes/fake_rpc.dart';
import '../activation_fixtures.dart';

void main() {
  late FakeRpc rpc;
  late ActivationRemoteDataSource source;

  setUp(() {
    rpc = FakeRpc()..response = activationPayload;
    source = ActivationRemoteDataSource(rpc.call);
  });

  test('S-10: redeem parses the server enrollment', () async {
    final result = await source.redeem('code', DateTime(2027, 3, 15));

    final value = (result as Success<ActivationResult>).value;
    expect(value.courseId, 'course-1');
    expect(value.courseSlug, 'sat-math');
    expect(value.courseTitle, 'SAT Math');
    expect(value.targetTestDate, DateTime(2027, 3, 15));
    expect(value.expiresAt, DateTime.utc(2027, 3, 30));
  });

  for (final date in [DateTime(2027, 3, 5, 0, 15), DateTime.utc(2027, 3, 5)]) {
    test('S-10: sends raw code and calendar date for $date', () async {
      await source.redeem(' ab12-cd34 ef56 ', date);

      expect(rpc.calls.single.$1, 'redeem_activation_code');
      expect(rpc.calls.single.$2, {
        'p_code': ' ab12-cd34 ef56 ',
        'p_target_test_date': '2027-03-05',
      });
    });
  }

  for (final code in [
    ErrorCodes.codeInvalid,
    ErrorCodes.codeUsed,
    ErrorCodes.alreadyEnrolled,
  ]) {
    test('S-10: returned $code becomes Failure', () async {
      rpc.response = {'ok': false, 'error': code};

      final result = await source.redeem('guess', DateTime(2027, 3, 15));

      expect((result as Failure).error.code, code);
      expect(ErrorCodes.isServerCode(code), isTrue);
    });
  }

  for (final code in [
    ErrorCodes.rateLimited,
    ErrorCodes.notAuthenticated,
    ErrorCodes.invalidInput,
  ]) {
    test('S-10: raised $code uses the shared mapper', () async {
      rpc.error = PostgrestException(message: code);

      final result = await source.redeem('code', DateTime(2027, 3, 15));

      expect((result as Failure).error, AppError(code, code));
    });
  }

  for (final error in [
    const SocketException('offline'),
    TimeoutException('timeout'),
    ClientException('offline'),
  ]) {
    test('S-10: transport $error becomes network Failure', () async {
      rpc.error = error;

      final result = await source.redeem('code', DateTime(2027, 3, 15));

      expect((result as Failure).error.code, ErrorCodes.network);
    });
  }

  test('S-10: unknown raised error becomes internal Failure', () async {
    rpc.error = const PostgrestException(message: 'database details');

    final result = await source.redeem('code', DateTime(2027, 3, 15));

    expect((result as Failure).error.code, ErrorCodes.internal);
  });

  for (final payload in <Object?>[
    null,
    <Object?>[],
    <String, Object?>{},
    {'ok': false},
    {'ok': false, 'error': 'database details'},
    {...activationPayload, 'ok': 'true'},
    {...activationPayload, 'course_id': null},
    {...activationPayload, 'target_test_date': 'not-a-date'},
    {...activationPayload, 'expires_at': 'not-a-date'},
  ]) {
    test('S-10: malformed $payload becomes internal Failure', () async {
      rpc.response = payload;

      final result = await source.redeem('code', DateTime(2027, 3, 15));

      expect((result as Failure).error.code, ErrorCodes.internal);
    });
  }
}
