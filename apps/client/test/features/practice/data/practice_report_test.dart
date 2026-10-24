import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/practice/data/datasources/practice_remote_data_source.dart';
import 'package:sat_east_client/features/practice/data/repositories/practice_repository_impl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/fakes/fake_rpc.dart';

void main() {
  for (final existing in [false, true]) {
    test(
      'QB-04: report existing=$existing is success and sends exact RPC params',
      () async {
        final rpc = FakeRpc()
          ..response = {'ok': true, 'report_id': 'r1', 'existing': existing};
        final repo = PracticeRepositoryImpl(PracticeRemoteDataSource(rpc.call));
        expect(
          await repo.report('q1', 'typo', 'Plain text'),
          isA<Success<void>>(),
        );
        expect(rpc.calls.single.$1, 'report_question');
        expect(rpc.calls.single.$2, {
          'p_question_id': 'q1',
          'p_reason': 'typo',
          'p_note': 'Plain text',
        });
      },
    );
  }
  test('QB-04: returned rate limit maps to failure without throwing', () async {
    final rpc = FakeRpc()..response = {'ok': false, 'error': 'rate_limited'};
    final repo = PracticeRepositoryImpl(PracticeRemoteDataSource(rpc.call));
    expect(
      (await repo.report('q1', 'other', null) as Failure<void>).error.code,
      'rate_limited',
    );
    expect(rpc.calls.single.$2['p_note'], isNull);
  });
  for (final code in ['invalid_input', 'not_authenticated']) {
    test('QB-04: raised $code is mapped', () async {
      final rpc = FakeRpc()..error = PostgrestException(message: code);
      final repo = PracticeRepositoryImpl(PracticeRemoteDataSource(rpc.call));
      expect(
        (await repo.report('q1', 'other', null) as Failure<void>).error.code,
        code,
      );
    });
  }
  test('QB-04: report transport error maps to network', () async {
    final rpc = FakeRpc()..error = TimeoutException('PRIVATE transport detail');
    final repo = PracticeRepositoryImpl(PracticeRemoteDataSource(rpc.call));
    expect(
      (await repo.report('q1', 'other', null) as Failure<void>).error.code,
      'network',
    );
  });
  for (final raw in <Object?>[
    null,
    {},
    {'ok': true},
    {'ok': true, 'report_id': 'r1', 'existing': 'yes'},
    {'ok': false, 'error': 'PRIVATE detail'},
  ]) {
    test('QB-04: malformed report response is internal: $raw', () async {
      final rpc = FakeRpc()..response = raw;
      final repo = PracticeRepositoryImpl(PracticeRemoteDataSource(rpc.call));
      expect(
        (await repo.report('q1', 'other', null) as Failure<void>).error.code,
        'internal',
      );
    });
  }
}
