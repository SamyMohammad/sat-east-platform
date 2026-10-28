import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/attempts/skill_result.dart';
import 'package:sat_east_client/features/quiz/data/models/quiz_model.dart';
import 'package:sat_east_client/features/quiz/domain/entities/quiz.dart';

import 'quiz_fixture.dart';

void main() {
  test('ANL-02: report_parses_skills', () {
    final payload = quizReportPayload()
      ..['skills'] = [
        {'code': 'ALG', 'name': 'Linear equations', 'correct': 2, 'total': 3},
      ];
    final report = quizReportFromJson(payload, 'a1');
    expect(report.skills, const [
      SkillResult(
        code: 'ALG',
        name: 'Linear equations',
        correct: 2,
        total: 3,
      ),
    ]);
    expect(report, quizReportFromJson(payload, 'a1'));
    expect(report, isNot(quizReportFromJson(quizReportPayload(), 'a1')));
  });

  test('ANL-02: old_report_without_skills_parses_empty', () {
    expect(quizReportFromJson(quizReportPayload(), 'a1').skills, isEmpty);
  });

  for (final invalid in <Object?>[
    null,
    {},
    [null],
    [
      {'code': '', 'name': 'Linear equations', 'correct': 1, 'total': 2},
    ],
    [
      {'code': 'ALG', 'name': 1, 'correct': 1, 'total': 2},
    ],
    [
      {'code': 'ALG', 'name': 'Linear equations', 'correct': -1, 'total': 2},
    ],
    [
      {'code': 'ALG', 'name': 'Linear equations', 'correct': 1.5, 'total': 2},
    ],
    [
      {'code': 'ALG', 'name': 'Linear equations', 'correct': 3, 'total': 2},
    ],
    [
      {'code': 'ALG', 'name': 'Linear equations', 'correct': 0, 'total': 0},
    ],
  ]) {
    test('ANL-02: rejects malformed skills $invalid', () {
      final payload = quizReportPayload()..['skills'] = invalid;
      expect(() => quizReportFromJson(payload, 'a1'), throwsFormatException);
    });
  }

  test(
    'PRC-03: parses a new quiz with server timing and ordered questions',
    () {
      final quiz = quizSessionFromJson(quizSessionPayload());

      expect(quiz.attemptId, 'a1');
      expect(quiz.title, '1.1 Linear equations');
      expect(quiz.timeLimit, const Duration(seconds: 180));
      expect(quiz.warnAt, const Duration(seconds: 300));
      expect(quiz.deadline, DateTime.utc(2026, 10, 17, 12, 3));
      expect(quiz.serverNow, DateTime.utc(2026, 10, 17, 12));
      expect(quiz.deadline.isUtc, isTrue);
      expect(quiz.serverNow.isUtc, isTrue);
      expect(quiz.questions.map((q) => q.id), ['q2', 'q1']);
      expect(quiz.questions.first.kind, QuizKind.spr);
      expect(quiz.questions.first.difficulty, 'H');
      expect(quiz.questions.first.stemMd, 'Solve x.');
      expect(quiz.questions.first.choices, isEmpty);
      expect(quiz.questions.last.kind, QuizKind.mcq);
      expect(quiz.questions.last.choices, [
        const QuizChoice('A', '1'),
        const QuizChoice('B', '2'),
      ]);
      expect(quiz.answers, isEmpty);
      expect(quiz.clientSeq, 0);
    },
  );

  test('PRC-03: resume restores raw answers, cleared marks and sequence', () {
    final payload = quizSessionPayload()
      ..['answers'] = [
        {'question_id': 'q1', 'answer': ' B ', 'marked': false},
        {'question_id': 'q2', 'answer': null, 'marked': true},
      ]
      ..['client_seq'] = 7;

    final quiz = quizSessionFromJson(payload);

    expect(quiz.answers, {
      'q1': const SavedAnswer(answer: ' B ', marked: false),
      'q2': const SavedAnswer(marked: true),
    });
    expect(quiz.clientSeq, 7);
  });

  test('PRC-03: report carries the attempt id it was parsed for', () {
    expect(quizReportFromJson(quizReportPayload(), 'a9').attemptId, 'a9');
  });

  test('PRC-03: parses passed report and next topic', () {
    final report = quizReportFromJson(quizReportPayload(), 'a1');

    expect(report.scoreRaw, 9);
    expect(report.scoreTotal, 12);
    expect(report.scorePct, 75.0);
    expect(report.passMark, 75);
    expect(report.passed, isTrue);
    expect(report.nextTopic, (id: 't2', title: 'Quadratics'));
    expect(report.retakeAt, isNull);
  });

  test('PRC-03: failed report retains cooldown and nullable next topic', () {
    final payload = quizReportPayload()
      ..['score_raw'] = 8
      ..['score_pct'] = 66.67
      ..['passed'] = false
      ..['next_topic'] = null
      ..['retake_at'] = '2026-10-18T15:00:00+03:00';

    final report = quizReportFromJson(payload, 'a1');

    expect(report.scorePct, 66.67);
    expect(report.passed, isFalse);
    expect(report.nextTopic, isNull);
    expect(report.retakeAt, DateTime.utc(2026, 10, 18, 12));
    expect(report.retakeAt!.isUtc, isTrue);
  });

  test(
    'PRC-03: keeps server passed flag and next topic after a prior pass',
    () {
      final payload = quizReportPayload()..['passed'] = false;

      final report = quizReportFromJson(payload, 'a1');

      expect(report.passed, isFalse);
      expect(report.nextTopic, (id: 't2', title: 'Quadratics'));
    },
  );

  for (final (payload, outcome) in [
    ({'ok': true}, SaveOutcome.saved),
    ({'ok': true, 'stale': false}, SaveOutcome.saved),
    ({'ok': true, 'stale': true}, SaveOutcome.stale),
  ]) {
    test('PRC-03: parses save acknowledgement $payload', () {
      expect(saveOutcomeFromJson(payload), outcome);
    });
  }

  for (final payload in <Map<String, Object?>>[
    {},
    {'ok': false},
    {'ok': 'true'},
    {'ok': true, 'stale': null},
    {'ok': true, 'stale': 1},
  ]) {
    test('PRC-03: rejects invalid save acknowledgement $payload', () {
      expect(() => saveOutcomeFromJson(payload), throwsFormatException);
    });
  }

  for (final (field, invalid) in <(String, Object?)>[
    ('attempt_id', null),
    ('attempt_id', ''),
    ('title', 7),
    ('time_limit_s', 0),
    ('time_limit_s', 1.5),
    ('warn_s', -1),
    ('warn_s', '300'),
    ('client_seq', -1),
    ('client_seq', 0.5),
    ('deadline', 'tomorrow'),
    ('deadline', '2026-10-17T12:03:00'),
    ('server_now', 1234),
    ('server_now', '2026-10-17T12:00:00'),
    ('questions', null),
    ('questions', <Object?>[]),
    ('answers', null),
    ('answers', {}),
  ]) {
    test('PRC-03: rejects invalid session $field=$invalid', () {
      final payload = quizSessionPayload()..[field] = invalid;
      expect(() => quizSessionFromJson(payload), throwsFormatException);
    });
  }

  for (final field in quizSessionPayload().keys) {
    test('PRC-03: rejects missing session $field', () {
      final payload = quizSessionPayload()..remove(field);
      expect(() => quizSessionFromJson(payload), throwsFormatException);
    });
  }

  for (final (field, invalid) in <(String, Object?)>[
    ('id', ''),
    ('id', 3),
    ('type', 'essay'),
    ('difficulty', 'X'),
    ('difficulty', null),
    ('stem_md', null),
    ('choices', null),
    ('choices', [1]),
    (
      'choices',
      [
        {'label': 'A'},
      ],
    ),
    (
      'choices',
      [
        {'label': 1, 'body_md': 'body'},
      ],
    ),
  ]) {
    test('PRC-03: rejects invalid question $field=$invalid', () {
      final payload = quizSessionPayload();
      final question =
          (payload['questions']! as List<Object?>).last!
              as Map<String, Object?>;
      question[field] = invalid;
      expect(() => quizSessionFromJson(payload), throwsFormatException);
    });
  }

  test('PRC-03: rejects duplicate question ids', () {
    final payload = quizSessionPayload();
    final questions = payload['questions']! as List<Object?>;
    questions.add(questions.first);
    expect(() => quizSessionFromJson(payload), throwsFormatException);
  });

  for (final answers in <List<Object?>>[
    [null],
    [
      {'question_id': 'q1', 'marked': true},
    ],
    [
      {'question_id': 'q1', 'answer': 7, 'marked': true},
    ],
    [
      {'question_id': 'q1', 'answer': 'B', 'marked': 'yes'},
    ],
    [
      {'question_id': 'missing', 'answer': null, 'marked': false},
    ],
    [
      {'question_id': 'q1', 'answer': 'B', 'marked': true},
      {'question_id': 'q1', 'answer': null, 'marked': false},
    ],
  ]) {
    test(
      'PRC-03: rejects malformed or inconsistent saved answers $answers',
      () {
        final payload = quizSessionPayload()..['answers'] = answers;
        expect(() => quizSessionFromJson(payload), throwsFormatException);
      },
    );
  }

  for (final (field, invalid) in <(String, Object?)>[
    ('score_raw', -1),
    ('score_raw', 13),
    ('score_raw', 1.5),
    ('score_total', 0),
    ('score_total', '12'),
    ('score_pct', -1),
    ('score_pct', 101),
    ('score_pct', double.nan),
    ('score_pct', double.infinity),
    ('pass_mark', -1),
    ('pass_mark', 101),
    ('pass_mark', 75.5),
    ('passed', 'true'),
    ('next_topic', 1),
    ('next_topic', {'id': 't2'}),
    ('next_topic', {'id': '', 'title': 'Next'}),
    ('next_topic', {'id': 't2', 'title': 1}),
    ('retake_at', 'tomorrow'),
    ('retake_at', '2026-10-18T12:00:00'),
  ]) {
    test('PRC-03: rejects invalid report $field=$invalid', () {
      final payload = quizReportPayload()..[field] = invalid;
      expect(() => quizReportFromJson(payload, 'a1'), throwsFormatException);
    });
  }

  for (final field in quizReportPayload().keys) {
    test('PRC-03: rejects missing report $field including nullable fields', () {
      final payload = quizReportPayload()..remove(field);
      expect(() => quizReportFromJson(payload, 'a1'), throwsFormatException);
    });
  }

  test('PRC-03: parsed entities have value equality', () {
    final first = quizSessionFromJson(quizSessionPayload());
    final second = quizSessionFromJson(quizSessionPayload());
    expect(first, second);
    expect(first.hashCode, second.hashCode);
    expect(
      quizReportFromJson(quizReportPayload(), 'a1'),
      quizReportFromJson(quizReportPayload(), 'a1'),
    );
  });
}
