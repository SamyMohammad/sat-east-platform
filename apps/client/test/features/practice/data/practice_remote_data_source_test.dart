import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/practice/data/datasources/practice_remote_data_source.dart';
import 'package:sat_east_client/features/practice/domain/entities/practice.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/fakes/fake_rpc.dart';

const Map<String, Object?> _set = {
  'attempt_id': 'a1',
  'rep_target': 2,
  'questions': [
    {
      'id': 'q1',
      'type': 'mcq',
      'difficulty': 'E',
      'stem_md': 'What is 1+1?',
      'choices': [
        {'label': 'A', 'body_md': '1'},
        {'label': 'B', 'body_md': '2'},
      ],
    },
    {
      'id': 'q2',
      'type': 'spr',
      'difficulty': 'H',
      'stem_md': 'Solve x.',
      'choices': <Object?>[],
    },
  ],
};

Future<Result<CheckResult>> _check(PracticeRemoteDataSource source) =>
    source.check(attemptId: 'a1', questionId: 'q1', answer: 'B', timeMs: 4200);

void main() {
  late FakeRpc rpc;
  late PracticeRemoteDataSource source;

  setUp(() {
    rpc = FakeRpc()..response = _set;
    source = PracticeRemoteDataSource(rpc.call);
  });

  group('PRC-01: PracticeRemoteDataSource.start', () {
    test('PRC-01: parses the set and sends p_topic_id', () async {
      final result = await source.start('t1');

      expect(rpc.calls.single.$1, 'get_practice_questions');
      expect(rpc.calls.single.$2, {'p_topic_id': 't1'});
      final set = (result as Success<PracticeSet>).value;
      expect(set.attemptId, 'a1');
      expect(set.repTarget, 2);
      expect(set.questions, hasLength(2));
      expect(set.questions[0].kind, PracticeKind.mcq);
      expect(set.questions[0].difficulty, 'E');
      expect(set.questions[0].choices[1], const PracticeChoice('B', '2'));
      expect(set.questions[1].kind, PracticeKind.spr);
      expect(set.questions[1].choices, isEmpty);
    });

    for (final code in [
      ErrorCodes.topicLocked,
      ErrorCodes.poolExhausted,
      ErrorCodes.accessExpired,
      ErrorCodes.notAuthenticated,
      ErrorCodes.invalidInput,
      ErrorCodes.notEnrolled,
    ]) {
      test('PRC-01: maps $code to a Failure', () async {
        rpc.error = PostgrestException(message: code);

        final result = await source.start('t1');

        expect((result as Failure).error, AppError(code, code));
      });
    }

    test('PRC-01: malformed payload gives internal Failure', () async {
      rpc.response = {'attempt_id': 'a1'};

      final result = await source.start('t1');

      expect((result as Failure).error.code, ErrorCodes.internal);
    });

    test('PRC-01: unknown question type gives internal Failure', () async {
      rpc.response = {
        ..._set,
        'questions': [
          {
            'id': 'q',
            'type': 'essay',
            'difficulty': 'E',
            'stem_md': 's',
            'choices': <Object?>[],
          },
        ],
      };

      final result = await source.start('t1');

      expect((result as Failure).error.code, ErrorCodes.internal);
    });

    test('PRC-01: SocketException gives network Failure', () async {
      rpc.error = const SocketException('down');

      final result = await source.start('t1');

      expect((result as Failure).error.code, ErrorCodes.network);
    });
  });

  group('PRC-01: PracticeRemoteDataSource.check', () {
    test('PRC-01: sends the exact params', () async {
      rpc.response = {
        'is_correct': true,
        'try': 1,
        'key': {'choice': 'B'},
        'explanation_md': 'because',
      };

      await _check(source);

      expect(rpc.calls.single.$1, 'check_practice_answer');
      expect(rpc.calls.single.$2, {
        'p_attempt_id': 'a1',
        'p_question_id': 'q1',
        'p_answer': 'B',
        'p_time_ms': 4200,
      });
    });

    test('PRC-01: correct parses to CheckCorrect with choice key', () async {
      rpc.response = {
        'is_correct': true,
        'try': 2,
        'key': {'choice': 'B'},
        'explanation_md': 'because',
      };

      final result = await _check(source);

      expect(
        (result as Success<CheckResult>).value,
        const CheckCorrect(
          tryNo: 2,
          key: ChoiceReveal('B'),
          explanationMd: 'because',
        ),
      );
    });

    test('PRC-01: text key parses to TextReveal', () async {
      rpc.response = {
        'is_correct': true,
        'try': 1,
        'key': {'text': '3/4'},
        'explanation_md': 'e',
      };

      final result = await _check(source);

      expect(
        ((result as Success<CheckResult>).value as CheckCorrect).key,
        const TextReveal('3/4'),
      );
    });

    test('PRC-01: wrong try 1 parses to CheckMiss', () async {
      rpc.response = {
        'is_correct': false,
        'try': 1,
        'hint_md': 'hint',
        'misconception_md': 'misc',
      };

      final result = await _check(source);

      expect(
        (result as Success<CheckResult>).value,
        const CheckMiss(hintMd: 'hint', misconceptionMd: 'misc'),
      );
    });

    test('PRC-01: wrong try 1 with null hint keeps nulls', () async {
      rpc.response = {
        'is_correct': false,
        'try': 1,
        'hint_md': null,
        'misconception_md': null,
      };

      final result = await _check(source);

      expect((result as Success<CheckResult>).value, const CheckMiss());
    });

    test('PRC-01: wrong try 2 parses to CheckRevealed', () async {
      rpc.response = {
        'is_correct': false,
        'try': 2,
        'key': {'choice': 'C'},
        'explanation_md': 'why',
      };

      final result = await _check(source);

      expect(
        (result as Success<CheckResult>).value,
        const CheckRevealed(key: ChoiceReveal('C'), explanationMd: 'why'),
      );
    });

    test('PRC-01: correct without key gives internal Failure', () async {
      rpc.response = {'is_correct': true, 'try': 1, 'explanation_md': 'e'};

      final result = await _check(source);

      expect((result as Failure).error.code, ErrorCodes.internal);
    });

    test('PRC-01: maps topic_locked to a Failure', () async {
      rpc.error = const PostgrestException(message: 'topic_locked');

      final result = await _check(source);

      expect(
        (result as Failure).error,
        const AppError('topic_locked', 'topic_locked'),
      );
    });

    test('PRC-01: SocketException gives network Failure', () async {
      rpc.error = const SocketException('down');

      final result = await _check(source);

      expect((result as Failure).error.code, ErrorCodes.network);
    });
  });

  for (final operation in ['start', 'check']) {
    Future<Result<Object?>> run() =>
        operation == 'start' ? source.start('t1') : _check(source);

    for (final payload in [null, 7, 'invalid', <Object?>[]]) {
      test('PRC-01: $operation rejects non-map $payload', () async {
        rpc.response = payload;

        final result = await run();

        expect((result as Failure).error.code, ErrorCodes.internal);
      });
    }

    test('PRC-01: $operation maps unknown errors to internal', () async {
      rpc.error = StateError('unexpected');

      final result = await run();

      expect((result as Failure).error.code, ErrorCodes.internal);
    });
  }
}
