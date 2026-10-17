import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/quiz/data/datasources/quiz_remote_data_source.dart';
import 'package:sat_east_client/features/quiz/domain/entities/quiz.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/fakes/fake_rpc.dart';
import 'quiz_fixture.dart';

Future<Result<SaveOutcome>> _save(
  QuizRemoteDataSource source, {
  String? answer = ' .5 ',
}) => source.save(
  attemptId: 'a1',
  questionId: 'q2',
  answer: answer,
  timeMs: 4321,
  marked: true,
  eliminated: ['A', 'C'],
  clientSeq: 8,
);

void main() {
  late FakeRpc rpc;
  late QuizRemoteDataSource source;

  setUp(() {
    rpc = FakeRpc();
    source = QuizRemoteDataSource(rpc.call);
  });

  test('PRC-03: start sends exact topic params and parses session', () async {
    rpc.response = quizSessionPayload();

    final result = await source.start('t1');

    expect(rpc.calls.single.$1, 'start_quiz');
    expect(rpc.calls.single.$2, {'p_topic_id': 't1'});
    expect((result as Success<QuizSession>).value.attemptId, 'a1');
  });

  for (final answer in [' .5 ', '', null]) {
    test('PRC-03: save forwards raw answer $answer and all params', () async {
      rpc.response = {'ok': true};

      final result = await _save(source, answer: answer);

      expect(rpc.calls.single.$1, 'save_answer');
      expect(rpc.calls.single.$2, {
        'p_attempt_id': 'a1',
        'p_question_id': 'q2',
        'p_answer': answer,
        'p_time_ms': 4321,
        'p_marked': true,
        'p_eliminated': ['A', 'C'],
        'p_client_seq': 8,
      });
      expect((result as Success<SaveOutcome>).value, SaveOutcome.saved);
    });
  }

  test('PRC-03: save returns stale without turning it into failure', () async {
    rpc.response = {'ok': true, 'stale': true};

    final result = await _save(source);

    expect((result as Success<SaveOutcome>).value, SaveOutcome.stale);
  });

  test('PRC-03: submit sends exact attempt params and parses report', () async {
    rpc.response = quizReportPayload();

    final result = await source.submit('a1');

    expect(rpc.calls.single.$1, 'submit_attempt');
    expect(rpc.calls.single.$2, {'p_attempt_id': 'a1'});
    expect((result as Success<QuizReport>).value.scoreRaw, 9);
  });

  for (final operation in ['start', 'save', 'submit']) {
    Future<Result<Object?>> run() => switch (operation) {
      'start' => source.start('t1'),
      'save' => _save(source),
      _ => source.submit('a1'),
    };

    for (final code in [
      ErrorCodes.notAuthenticated,
      ErrorCodes.invalidInput,
      ErrorCodes.notEnrolled,
      ErrorCodes.accessExpired,
      ErrorCodes.topicLocked,
      ErrorCodes.poolExhausted,
      ErrorCodes.practiceNeeded,
      ErrorCodes.cooldownActive,
      ErrorCodes.deadlinePassed,
    ]) {
      test('PRC-03: $operation maps server error $code', () async {
        rpc.error = PostgrestException(message: code);

        final result = await run();

        expect((result as Failure).error, AppError(code, code));
      });
    }

    for (final payload in <Object?>[null, 1, 'invalid', <Object?>[], {}]) {
      test('PRC-03: $operation maps malformed payload $payload', () async {
        rpc.response = payload;

        final result = await run();

        expect((result as Failure).error.code, ErrorCodes.internal);
      });
    }

    test('PRC-03: $operation maps network failure', () async {
      rpc.error = const SocketException('offline');

      final result = await run();

      expect((result as Failure).error.code, ErrorCodes.network);
    });

    test('PRC-03: $operation maps unexpected failure', () async {
      rpc.error = StateError('unexpected');

      final result = await run();

      expect((result as Failure).error.code, ErrorCodes.internal);
    });
  }
}
