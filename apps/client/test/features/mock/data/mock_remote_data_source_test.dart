import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/attempts/attempt_question.dart';
import 'package:sat_east_client/core/attempts/save_outcome.dart';
import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/mock/data/datasources/mock_remote_data_source.dart';
import 'package:sat_east_client/features/mock/domain/entities/mock_entities.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/fakes/fake_rpc.dart';
import 'mock_fixtures.dart';

MockRemoteDataSource _source(FakeRpc rpc, {Map<String, Object?>? row}) =>
    MockRemoteDataSource(rpc.call, readResult: (id) async => row);

T _ok<T>(Result<T> r) => (r as Success<T>).value;

AppError _err<T>(Result<T> r) => (r as Failure<T>).error;

MockModule _module(Result<MockStage> r) => (_ok(r) as MockModuleStage).module;

void main() {
  group('hub', () {
    test('MCK-01: get_mock_hub sends p_course_id and parses all four states '
        'and active_group', () async {
      final rpc = FakeRpc()..response = hubJson();
      final hub = _ok(await _source(rpc).hub(courseId));
      expect(rpc.calls.single.$1, 'get_mock_hub');
      expect(rpc.calls.single.$2, equals({'p_course_id': courseId}));
      expect(hub.passedTopics, 7);
      expect(hub.activeGroup, groupId);
      expect(hub.forms.map((f) => f.state), [
        MockFormState.finished,
        MockFormState.inProgress,
        MockFormState.available,
        MockFormState.locked,
      ]);
      expect(hub.forms[3].formNo, 4);
      expect(hub.forms[3].k, 4);
      expect(hub.forms[3].need, 12);
    });

    test('MCK-01: hub with no active group and no forms', () async {
      final rpc = FakeRpc()
        ..response = {
          'passed_topics': 0,
          'forms': <Object?>[],
          'active_group': null,
        };
      final hub = _ok(await _source(rpc).hub(courseId));
      expect(hub.activeGroup, isNull);
      expect(hub.forms, isEmpty);
    });

    test('MCK-01: hub with an unknown state is malformed', () async {
      final rpc = FakeRpc()
        ..response = {
          'passed_topics': 0,
          'forms': [
            {'form_no': 1, 'k': 1, 'need': 3, 'state': 'bogus'},
          ],
          'active_group': null,
        };
      expect(_err(await _source(rpc).hub(courseId)).code, ErrorCodes.internal);
    });
  });

  group('stages', () {
    test('MCK-01: start_mock sends p_course_id and parses a module', () async {
      final rpc = FakeRpc()..response = moduleJson();
      final module = _module(await _source(rpc).start(courseId));
      expect(rpc.calls.single.$1, 'start_mock');
      expect(rpc.calls.single.$2, equals({'p_course_id': courseId}));
      expect(module.groupId, groupId);
      expect(module.moduleNo, 1);
      expect(module.attemptId, attemptId);
      expect(module.title, 'Module 1');
      expect(module.timeLimitS, 2100);
      expect(module.deadline, DateTime.utc(2026, 11, 17, 10, 35));
      expect(module.serverNow.isUtc, isTrue);
      expect(module.serverNow.microsecond, 456);
      expect(module.warnS, 300);
      expect(module.clientSeq, 4);
      expect(module.questions, hasLength(2));
      expect(module.questions[0].kind, AttemptKind.mcq);
      expect(module.questions[0].choices.map((c) => c.label), [
        'A',
        'B',
        'C',
        'D',
      ]);
      expect(module.questions[1].kind, AttemptKind.spr);
      expect(module.questions[1].choices, isEmpty);
    });

    test('MCK-01: the mock question has no difficulty', () async {
      final rpc = FakeRpc()..response = moduleJson();
      final module = _module(await _source(rpc).start(courseId));
      // The route must stay hidden: nothing may carry a difficulty.
      expect(module.questions.map((q) => q.difficulty), everyElement(isNull));
    });

    test(
      'MCK-01: module answers carry marked and eliminated choices',
      () async {
        final rpc = FakeRpc()..response = moduleJson();
        final module = _module(await _source(rpc).start(courseId));
        expect(module.answers['q1']!.answer, 'B');
        expect(module.answers['q1']!.marked, isTrue);
        expect(module.answers['q1']!.eliminated, {'A', 'D'});
        expect(module.answers['q2']!.answer, isNull);
        expect(module.answers['q2']!.eliminated, isEmpty);
      },
    );

    test('MCK-01: a null or missing eliminated array reads as empty', () async {
      final rpc = FakeRpc()
        ..response = moduleJson(
          answers: [
            {
              'question_id': 'q1',
              'answer': 'A',
              'marked': false,
              'eliminated': null,
            },
            {'question_id': 'q2', 'answer': '3', 'marked': false},
          ],
        );
      final module = _module(await _source(rpc).start(courseId));
      expect(module.answers['q1']!.eliminated, isEmpty);
      expect(module.answers['q2']!.eliminated, isEmpty);
    });

    test('MCK-01: malformed eliminated is rejected', () async {
      for (final bad in <Object?>[
        'A',
        5,
        <Object?>[1],
      ]) {
        final rpc = FakeRpc()
          ..response = moduleJson(
            answers: [
              {
                'question_id': 'q1',
                'answer': 'A',
                'marked': false,
                'eliminated': bad,
              },
            ],
          );
        expect(
          _err(await _source(rpc).start(courseId)).code,
          ErrorCodes.internal,
          reason: '$bad',
        );
      }
    });

    test(
      'MCK-01: get_mock_session sends p_group_id and parses the gap',
      () async {
        final rpc = FakeRpc()..response = gapJson();
        final stage = _ok(await _source(rpc).session(groupId));
        expect(rpc.calls.single.$1, 'get_mock_session');
        expect(rpc.calls.single.$2, equals({'p_group_id': groupId}));
        expect(
          stage,
          MockGapStage(
            groupId: groupId,
            gapUntil: DateTime.utc(2026, 11, 17, 10, 37),
            serverNow: DateTime.utc(2026, 11, 17, 10, 35, 1),
          ),
        );
      },
    );

    test(
      'MCK-01: start_mock_module2 sends p_group_id and parses module 2',
      () async {
        final rpc = FakeRpc()
          ..response = {...moduleJson(), 'module_no': 2, 'title': 'Module 2'};
        final module = _module(await _source(rpc).startModule2(groupId));
        expect(rpc.calls.single.$1, 'start_mock_module2');
        expect(rpc.calls.single.$2, equals({'p_group_id': groupId}));
        expect(module.moduleNo, 2);
      },
    );

    test('MCK-01: the finished stage carries the result id', () async {
      final rpc = FakeRpc()..response = finishedJson();
      expect(
        _ok(await _source(rpc).session(groupId)),
        const MockFinishedStage(groupId: groupId, resultId: resultId),
      );
    });

    test(
      'MCK-01: a module stage without questions is the started marker',
      () async {
        final rpc = FakeRpc()
          ..response = {'stage': 'module', 'group_id': groupId, 'module_no': 2};
        expect(
          _ok(await _source(rpc).submit(attemptId)),
          const MockModuleStartedStage(groupId: groupId, moduleNo: 2),
        );
      },
    );

    test(
      'MCK-01: submit_attempt sends p_attempt_id and parses a gap',
      () async {
        final rpc = FakeRpc()..response = gapJson();
        final stage = _ok(await _source(rpc).submit(attemptId));
        expect(rpc.calls.single.$1, 'submit_attempt');
        expect(rpc.calls.single.$2, equals({'p_attempt_id': attemptId}));
        expect(stage, isA<MockGapStage>());
      },
    );

    test('MCK-01: malformed stage payloads map to internal', () async {
      final payloads = <Object?>[
        null,
        'x',
        {'stage': 'nope', 'group_id': groupId},
        {'group_id': groupId},
        {'stage': 'gap', 'group_id': groupId},
        {...gapJson(), 'gap_until': 'tomorrow'},
        {...gapJson(), 'gap_until': '2026-11-17T10:37:00'},
        {'stage': 'finished', 'group_id': groupId},
        {'stage': 'finished', 'group_id': groupId, 'result_id': ''},
        {...moduleJson(), 'time_limit_s': 0},
        {...moduleJson(), 'deadline': 5},
        {...moduleJson(), 'questions': <Object?>[]},
        {...moduleJson(), 'module_no': 3},
        {...moduleJson(), 'warn_s': -1},
        {
          ...moduleJson(),
          'answers': [
            {'question_id': 'unknown', 'answer': null, 'marked': false},
          ],
        },
      ];
      for (final payload in payloads) {
        final rpc = FakeRpc()..response = payload;
        expect(
          _err(await _source(rpc).session(groupId)).code,
          ErrorCodes.internal,
          reason: '$payload',
        );
      }
    });

    test('MCK-01: server errors keep their code', () async {
      for (final code in [
        ErrorCodes.mockLocked,
        ErrorCodes.mockNoneAvailable,
        ErrorCodes.notEnrolled,
        ErrorCodes.accessExpired,
        ErrorCodes.rateLimited,
        ErrorCodes.mockSettingsInvalid,
      ]) {
        final rpc = FakeRpc()..error = PostgrestException(message: code);
        expect(_err(await _source(rpc).start(courseId)).code, code);
      }
    });
  });

  group('save', () {
    test('MCK-01: save_answer sends the exact params with p_eliminated as a '
        'list', () async {
      final rpc = FakeRpc()..response = {'ok': true};
      final outcome = _ok(
        await _source(rpc).save(
          attemptId: attemptId,
          questionId: 'q1',
          answer: 'B',
          timeMs: 1200,
          marked: true,
          eliminated: const ['A', 'D'],
          clientSeq: 5,
        ),
      );
      expect(outcome, SaveOutcome.saved);
      expect(rpc.calls.single.$1, 'save_answer');
      expect(
        rpc.calls.single.$2,
        equals({
          'p_attempt_id': attemptId,
          'p_question_id': 'q1',
          'p_answer': 'B',
          'p_time_ms': 1200,
          'p_marked': true,
          'p_eliminated': ['A', 'D'],
          'p_client_seq': 5,
        }),
      );
      expect(rpc.calls.single.$2['p_eliminated'], isA<List<String>>());
    });

    test('MCK-01: save_answer reports stale and cleared answers', () async {
      final rpc = FakeRpc()..response = {'ok': true, 'stale': true};
      final outcome = _ok(
        await _source(rpc).save(
          attemptId: attemptId,
          questionId: 'q1',
          timeMs: 0,
          marked: false,
          eliminated: const [],
          clientSeq: 6,
        ),
      );
      expect(outcome, SaveOutcome.stale);
      expect(rpc.calls.single.$2['p_answer'], isNull);
      expect(rpc.calls.single.$2['p_eliminated'], isEmpty);
    });

    test('MCK-01: save_answer deadline_passed is kept', () async {
      final rpc = FakeRpc()
        ..error = const PostgrestException(message: 'deadline_passed');
      final result = await _source(rpc).save(
        attemptId: attemptId,
        questionId: 'q1',
        timeMs: 0,
        marked: false,
        eliminated: const [],
        clientSeq: 1,
      );
      expect(_err(result).code, ErrorCodes.deadlinePassed);
    });
  });

  group('result', () {
    test('MCK-01: result parses scores, range and domains', () async {
      final rpc = FakeRpc();
      final result = _ok(
        await _source(rpc, row: resultRowJson()).result(resultId),
      );
      expect(rpc.calls, isEmpty);
      expect(result.id, resultId);
      expect(result.route, 'hard');
      expect(result.rawM1, 18);
      expect(result.rawM2, 15);
      expect(result.estLow, 560);
      expect(result.estHigh, 620);
      expect(result.domains, const [
        DomainScore(domain: 'Algebra', correct: 9, total: 13),
        DomainScore(
          domain: 'Geometry and Trigonometry',
          correct: 4,
          total: 7,
        ),
      ]);
    });

    test('MCK-01: result keeps a null range', () async {
      final result = _ok(
        await _source(
          FakeRpc(),
          row: resultRowJson(estLow: null, estHigh: null),
        ).result(resultId),
      );
      expect(result.estLow, isNull);
      expect(result.estHigh, isNull);
    });

    test('MCK-01: a missing row or a bad row fails with internal', () async {
      expect(
        _err(await _source(FakeRpc()).result(resultId)).code,
        ErrorCodes.internal,
      );
      expect(
        _err(
          await _source(
            FakeRpc(),
            row: {...resultRowJson(), 'raw_m1': 'x'},
          ).result(resultId),
        ).code,
        ErrorCodes.internal,
      );
    });

    test('MCK-01: a Postgrest error from the read is mapped', () async {
      final source = MockRemoteDataSource(
        FakeRpc().call,
        readResult: (_) async =>
            throw const PostgrestException(message: 'forbidden'),
      );
      expect(_err(await source.result(resultId)).code, ErrorCodes.forbidden);
    });
  });
}
