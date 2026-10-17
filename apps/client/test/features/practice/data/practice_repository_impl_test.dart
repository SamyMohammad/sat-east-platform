import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/practice/data/datasources/practice_remote_data_source.dart';
import 'package:sat_east_client/features/practice/data/repositories/practice_repository_impl.dart';
import 'package:sat_east_client/features/practice/domain/entities/practice.dart';
import 'package:sat_east_client/features/practice/domain/repositories/practice_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/fakes/fake_rpc.dart';

void main() {
  late FakeRpc rpc;
  late PracticeRepository repository;

  setUp(() {
    rpc = FakeRpc();
    repository = PracticeRepositoryImpl(PracticeRemoteDataSource(rpc.call));
  });

  test('PRC-01: repository delegates start and returns the set', () async {
    rpc.response = {
      'attempt_id': 'a1',
      'rep_target': 1,
      'questions': [
        {
          'id': 'q1',
          'type': 'spr',
          'difficulty': 'H',
          'stem_md': 'Solve.',
          'choices': <Object?>[],
        },
      ],
    };

    final result = await repository.start('topic');

    expect(rpc.calls.single.$1, 'get_practice_questions');
    expect(rpc.calls.single.$2, {'p_topic_id': 'topic'});
    expect((result as Success<PracticeSet>).value.attemptId, 'a1');
  });

  test('PRC-01: repository preserves start failures', () async {
    rpc.error = const PostgrestException(message: ErrorCodes.poolExhausted);

    final result = await repository.start('topic');

    expect(
      (result as Failure).error,
      const AppError(ErrorCodes.poolExhausted, ErrorCodes.poolExhausted),
    );
  });

  test('PRC-01: repository delegates every check argument', () async {
    rpc.response = {
      'is_correct': false,
      'try': 1,
      'hint_md': 'Hint.',
      'misconception_md': null,
    };

    final result = await repository.check(
      attemptId: 'attempt',
      questionId: 'question',
      answer: ' .5 ',
      timeMs: 1234,
    );

    expect(rpc.calls.single.$1, 'check_practice_answer');
    expect(rpc.calls.single.$2, {
      'p_attempt_id': 'attempt',
      'p_question_id': 'question',
      'p_answer': ' .5 ',
      'p_time_ms': 1234,
    });
    expect(
      (result as Success<CheckResult>).value,
      const CheckMiss(hintMd: 'Hint.'),
    );
  });

  test('PRC-01: repository preserves check failures', () async {
    rpc.error = const PostgrestException(message: ErrorCodes.accessExpired);

    final result = await repository.check(
      attemptId: 'attempt',
      questionId: 'question',
      answer: 'B',
      timeMs: 0,
    );

    expect(
      (result as Failure).error,
      const AppError(ErrorCodes.accessExpired, ErrorCodes.accessExpired),
    );
  });
}
