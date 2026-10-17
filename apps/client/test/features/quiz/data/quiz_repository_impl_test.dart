import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/quiz/data/datasources/quiz_remote_data_source.dart';
import 'package:sat_east_client/features/quiz/data/repositories/quiz_repository_impl.dart';
import 'package:sat_east_client/features/quiz/domain/entities/quiz.dart';
import 'package:sat_east_client/features/quiz/domain/repositories/quiz_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/fakes/fake_rpc.dart';
import 'quiz_fixture.dart';

void main() {
  late FakeRpc rpc;
  late QuizRepository repository;

  setUp(() {
    rpc = FakeRpc();
    repository = QuizRepositoryImpl(QuizRemoteDataSource(rpc.call));
  });

  test('PRC-03: repository delegates start', () async {
    rpc.response = quizSessionPayload();

    final result = await repository.start('topic');

    expect(rpc.calls.single.$1, 'start_quiz');
    expect(rpc.calls.single.$2, {'p_topic_id': 'topic'});
    expect((result as Success<QuizSession>).value.attemptId, 'a1');
  });

  test('PRC-03: repository delegates every save argument unchanged', () async {
    rpc.response = {'ok': true, 'stale': true};

    final result = await repository.save(
      attemptId: 'attempt',
      questionId: 'question',
      answer: ' 1/2 ',
      timeMs: -1,
      marked: false,
      eliminated: ['D', 'B'],
      clientSeq: 17,
    );

    expect(rpc.calls.single.$1, 'save_answer');
    expect(rpc.calls.single.$2, {
      'p_attempt_id': 'attempt',
      'p_question_id': 'question',
      'p_answer': ' 1/2 ',
      'p_time_ms': -1,
      'p_marked': false,
      'p_eliminated': ['D', 'B'],
      'p_client_seq': 17,
    });
    expect((result as Success<SaveOutcome>).value, SaveOutcome.stale);
  });

  test('PRC-03: repository delegates answer clearing', () async {
    rpc.response = {'ok': true};

    final result = await repository.save(
      attemptId: 'attempt',
      questionId: 'question',
      timeMs: 0,
      marked: true,
      eliminated: [],
      clientSeq: 18,
    );

    expect(rpc.calls.single.$2['p_answer'], isNull);
    expect(rpc.calls.single.$2, contains('p_answer'));
    expect((result as Success<SaveOutcome>).value, SaveOutcome.saved);
  });

  test('PRC-03: repository delegates submit', () async {
    rpc.response = quizReportPayload();

    final result = await repository.submit('attempt');

    expect(rpc.calls.single.$1, 'submit_attempt');
    expect(rpc.calls.single.$2, {'p_attempt_id': 'attempt'});
    expect((result as Success<QuizReport>).value.passed, isTrue);
  });

  for (final operation in ['start', 'save', 'submit']) {
    test('PRC-03: repository preserves $operation failures', () async {
      rpc.error = const PostgrestException(message: ErrorCodes.accessExpired);

      final result = await switch (operation) {
        'start' => repository.start('topic'),
        'save' => repository.save(
          attemptId: 'attempt',
          questionId: 'question',
          timeMs: 0,
          marked: false,
          eliminated: [],
          clientSeq: 1,
        ),
        _ => repository.submit('attempt'),
      };

      expect(
        (result as Failure).error,
        const AppError(ErrorCodes.accessExpired, ErrorCodes.accessExpired),
      );
    });
  }
}
