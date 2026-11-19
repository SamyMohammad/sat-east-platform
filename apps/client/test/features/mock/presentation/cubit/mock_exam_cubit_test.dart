import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/attempts/attempt_question.dart';
import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/mock/domain/entities/mock_entities.dart';
import 'package:sat_east_client/features/mock/presentation/cubit/mock_exam_cubit.dart';
import 'package:sat_east_client/features/mock/presentation/cubit/mock_exam_state.dart';

import '../../../../support/in_memory_pending_answers.dart';
import '../../mock_fakes.dart';

Future<void> _settle() async {
  for (var i = 0; i < 8; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

class _Harness {
  _Harness() {
    cubit = MockExamCubit(
      repo,
      () => clock,
      (period) {
        expect(period, const Duration(seconds: 1));
        return ticks.stream;
      },
      pending,
      fakeGroupId,
    );
  }

  final repo = FakeMockRepository();
  final pending = InMemoryPendingAnswers();
  final ticks = StreamController<void>.broadcast(sync: true);
  DateTime clock = DateTime.utc(2026, 11, 17, 12);
  late final MockExamCubit cubit;

  MockExamModule get module => cubit.state as MockExamModule;
  MockExamGap get gap => cubit.state as MockExamGap;
  MockExamFinished get finished => cubit.state as MockExamFinished;

  MockStage moduleStage({
    int moduleNo = 1,
    Duration remaining = const Duration(minutes: 35),
    Map<String, SavedAnswer> answers = const {},
    int clientSeq = 0,
    Duration serverAhead = Duration.zero,
  }) => MockModuleStage(
    fakeModule(
      serverNow: clock.add(serverAhead),
      moduleNo: moduleNo,
      remaining: remaining,
      answers: answers,
      clientSeq: clientSeq,
    ),
  );

  MockStage gapStage([Duration wait = const Duration(minutes: 2)]) =>
      MockGapStage(
        groupId: fakeGroupId,
        gapUntil: clock.add(wait),
        serverNow: clock,
      );

  void tick([Duration advance = const Duration(seconds: 1)]) {
    clock = clock.add(advance);
    ticks.add(null);
  }

  /// Starts a module-1 run.
  Future<void> startModule([MockStage? stage]) async {
    repo.sessionResult = Success(stage ?? moduleStage());
    await cubit.start();
  }

  Future<void> close() async {
    await cubit.close();
    await ticks.close();
  }
}

_Harness _harness() {
  final h = _Harness();
  addTearDown(h.close);
  return h;
}

void main() {
  group('start', () {
    test(
      'MCK-01: a module stage opens the module with the server clock',
      () async {
        final h = _harness();
        expect(h.cubit.state, isA<MockExamLoading>());
        await h.startModule();
        expect(h.repo.sessionCalls, [fakeGroupId]);
        expect(h.module.module.moduleNo, 1);
        expect(h.module.index, 0);
        expect(h.module.remaining, const Duration(minutes: 35));
        expect(h.module.answers, isEmpty);
        expect(h.module.submitting, isFalse);
      },
    );

    test(
      'MCK-01: a started-module marker is followed with session()',
      () async {
        final h = _harness();
        h.repo.sessionQueue.addAll([
          const Success(
            MockModuleStartedStage(groupId: fakeGroupId, moduleNo: 2),
          ),
          Success(h.moduleStage(moduleNo: 2)),
        ]);
        await h.cubit.start();
        expect(h.repo.sessionCalls, hasLength(2));
        expect(h.module.module.moduleNo, 2);
      },
    );

    test('MCK-01: a marker that never turns into a module fails', () async {
      final h = _harness();
      h.repo.sessionResult = const Success(
        MockModuleStartedStage(groupId: fakeGroupId, moduleNo: 2),
      );
      await h.cubit.start();
      expect((h.cubit.state as MockExamFailed).error.code, ErrorCodes.internal);
      expect(h.repo.sessionCalls, hasLength(2));
    });

    test('MCK-01: a gap stage opens the countdown', () async {
      final h = _harness();
      await h.startModule(h.gapStage(const Duration(seconds: 90)));
      expect(h.gap.remaining, const Duration(seconds: 90));
      expect(h.gap.startingModule2, isFalse);
      expect(h.gap.groupId, fakeGroupId);
    });

    test('MCK-01: a finished stage loads the result', () async {
      final h = _harness();
      await h.startModule(
        const MockFinishedStage(groupId: fakeGroupId, resultId: 'r1'),
      );
      expect(h.finished.result, fakeResult);
      expect(h.finished.resultError, isNull);
      expect(h.repo.resultCalls, ['r1']);
    });

    test('MCK-01: a session failure is Failed', () async {
      final h = _harness();
      h.repo.sessionResult = const Failure(AppError(ErrorCodes.network));
      await h.cubit.start();
      expect(
        h.cubit.state,
        const MockExamFailed(AppError(ErrorCodes.network)),
      );
    });

    test('MCK-01: start shows loading until the response settles', () async {
      final h = _harness();
      final gate = h.repo.sessionGate = Completer<void>();
      h.repo.sessionResult = Success(h.moduleStage());
      final pending = h.cubit.start();
      expect(h.cubit.state, isA<MockExamLoading>());
      gate.complete();
      await pending;
      expect(h.cubit.state, isA<MockExamModule>());
    });

    test(
      'MCK-01: the clock follows server_now, not the device clock',
      () async {
        final h = _harness();
        await h.startModule(
          h.moduleStage(
            remaining: const Duration(minutes: 10),
            serverAhead: const Duration(hours: 1),
          ),
        );
        expect(h.module.remaining, const Duration(minutes: 10));
        h.tick(const Duration(minutes: 1));
        expect(h.module.remaining, const Duration(minutes: 9));
      },
    );
  });

  group('resume', () {
    test('MCK-01: the outbox wins over the server answers', () async {
      final h = _harness();
      h.pending.put(
        'attempt-1',
        'q1',
        answer: 'C',
        marked: true,
        timeMs: 900,
        eliminated: {'D'},
      );
      await h.startModule(
        h.moduleStage(
          clientSeq: 4,
          answers: const {
            'q1': SavedAnswer(answer: 'B', marked: false, eliminated: {'A'}),
            'q2': SavedAnswer(answer: '7', marked: true),
          },
        ),
      );
      expect(h.module.answers, {'q1': 'C', 'q2': '7'});
      expect(h.module.marked, {'q1', 'q2'});
      expect(h.module.eliminated['q1'], {'D'});
      await _settle();
      // The unacknowledged answer is re-sent with the next client_seq.
      expect(h.repo.saves.single.clientSeq, 5);
      expect(h.repo.saves.single.answer, 'C');
      expect(h.repo.saves.single.eliminated, ['D']);
      expect(h.pending.forAttempt('attempt-1'), isEmpty);
    });

    test(
      'MCK-01: server answers alone restore marks and eliminations',
      () async {
        final h = _harness();
        await h.startModule(
          h.moduleStage(
            answers: const {
              'q1': SavedAnswer(
                answer: 'B',
                marked: true,
                eliminated: {'A', 'C'},
              ),
            },
          ),
        );
        expect(h.module.answers['q1'], 'B');
        expect(h.module.marked, {'q1'});
        expect(h.module.eliminated['q1'], {'A', 'C'});
        expect(h.repo.saves, isEmpty);
      },
    );
  });

  group('answering', () {
    test(
      'MCK-01: saves go through the queue with increasing client_seq',
      () async {
        final h = _harness();
        await h.startModule(h.moduleStage(clientSeq: 4));
        h.cubit.select('B');
        await _settle();
        h.cubit.toggleEliminate('A');
        await _settle();
        h.cubit.toggleMark();
        await _settle();
        h.cubit.goTo(1);
        h.cubit.sprChanged('3/4');
        await _settle();
        final saves = h.repo.saves;
        expect(saves.map((s) => s.clientSeq), [5, 6, 7, 8]);
        expect(saves[0].questionId, 'q1');
        expect(saves[0].answer, 'B');
        expect(saves[0].marked, isFalse);
        expect(saves[0].eliminated, isEmpty);
        expect(saves[1].eliminated, ['A']);
        expect(saves[1].answer, 'B');
        expect(saves[2].marked, isTrue);
        expect(saves[3].questionId, 'q2');
        expect(saves[3].answer, '3/4');
        expect(saves.every((s) => s.attemptId == 'attempt-1'), isTrue);
        expect(h.pending.forAttempt('attempt-1'), isEmpty);
      },
    );

    test('MCK-01: a change is in the outbox before the save returns', () async {
      final h = _harness();
      await h.startModule();
      h.repo.saveGate = Completer<void>();
      h.cubit.select('C');
      h.cubit.toggleEliminate('D');
      await _settle();
      final entry = h.pending.forAttempt('attempt-1')['q1']!;
      expect(entry.answer, 'C');
      expect(entry.eliminated, {'D'});
      h.repo.saveGate!.complete();
      await _settle();
    });

    test('MCK-01: toggling an elimination twice restores the choice', () async {
      final h = _harness();
      await h.startModule();
      h.cubit.toggleEliminate('A');
      expect(h.module.eliminated['q1'], {'A'});
      h.cubit.toggleEliminate('A');
      expect(h.module.eliminated['q1'] ?? <String>{}, isEmpty);
      await _settle();
    });

    test('MCK-01: invalid input is ignored', () async {
      final h = _harness();
      await h.startModule();
      h.cubit
        ..select('Z')
        ..sprChanged('1')
        ..toggleEliminate('Z');
      h.cubit.select('B');
      // The selected answer cannot be eliminated.
      h.cubit.toggleEliminate('B');
      await _settle();
      expect(h.repo.saves, hasLength(1));
      h.cubit.goTo(1);
      h.cubit
        ..select('A')
        ..toggleEliminate('A');
      await _settle();
      expect(h.repo.saves, hasLength(1));
    });

    test('MCK-01: navigation stays in range and the timer toggles', () async {
      final h = _harness();
      await h.startModule();
      h.cubit
        ..goTo(-1)
        ..goTo(3)
        ..prev();
      expect(h.module.index, 0);
      h.cubit.next();
      expect(h.module.index, 1);
      h.cubit.goTo(2);
      h.cubit.next();
      expect(h.module.index, 2);
      h.cubit.prev();
      expect(h.module.index, 1);
      expect(h.module.timerHidden, isFalse);
      h.cubit.toggleTimer();
      expect(h.module.timerHidden, isTrue);
    });

    test(
      'MCK-01: the review page opens, closes, and a jump closes it',
      () async {
        final h = _harness();
        await h.startModule();
        h.cubit.openReview();
        expect(h.module.reviewOpen, isTrue);
        h.cubit.closeReview();
        expect(h.module.reviewOpen, isFalse);
        h.cubit
          ..openReview()
          ..goTo(2);
        expect(h.module.reviewOpen, isFalse);
        expect(h.module.index, 2);
      },
    );
  });

  group('submit', () {
    test(
      'MCK-01: time up flushes the outbox first, then submits once',
      () async {
        final h = _harness();
        await h.startModule();
        final gate = h.repo.saveGate = Completer<void>();
        h.cubit.select('A');
        await _settle();
        h.repo.submitResult = Success(h.gapStage());
        h.tick(const Duration(minutes: 36));
        await _settle();
        expect(h.module.remaining, Duration.zero);
        expect(h.repo.submitCalls, isEmpty, reason: 'save still in flight');
        gate.complete();
        await _settle();
        h
          ..tick()
          ..tick();
        await _settle();
        expect(h.repo.events, ['save', 'submit']);
        expect(h.repo.submitCalls, ['attempt-1']);
        expect(h.cubit.state, isA<MockExamGap>());
      },
    );

    test('MCK-01: nothing can be edited after time is up', () async {
      final h = _harness();
      await h.startModule();
      h.repo.submitGate = Completer<void>();
      h.tick(const Duration(minutes: 36));
      await _settle();
      h.cubit
        ..select('A')
        ..toggleMark();
      await _settle();
      expect(h.repo.saves, isEmpty);
      h.repo.submitGate!.complete();
      await _settle();
    });

    test(
      'MCK-01: a submit failure shows an error and a retry succeeds',
      () async {
        final h = _harness();
        await h.startModule();
        h.repo.submitResult = const Failure(AppError(ErrorCodes.network));
        await h.cubit.submitModule();
        expect(h.module.submitting, isFalse);
        expect(h.module.submitError, const AppError(ErrorCodes.network));
        expect(h.repo.submitCalls, hasLength(1));
        h.repo.submitResult = Success(h.gapStage());
        await h.cubit.submitModule();
        expect(h.repo.submitCalls, hasLength(2));
        expect(h.cubit.state, isA<MockExamGap>());
      },
    );

    test('MCK-01: a second submit while one runs is ignored', () async {
      final h = _harness();
      await h.startModule();
      final gate = h.repo.submitGate = Completer<void>();
      h.repo.submitResult = Success(h.gapStage());
      final first = h.cubit.submitModule();
      await _settle();
      expect(h.module.submitting, isTrue);
      final second = h.cubit.submitModule();
      await _settle();
      gate.complete();
      await Future.wait([first, second]);
      expect(h.repo.submitCalls, hasLength(1));
    });

    test(
      'MCK-01: unsaved answers block a manual submit with an error',
      () async {
        final h = _harness();
        await h.startModule();
        h.repo.saveResult = const Failure(AppError(ErrorCodes.network));
        h.cubit.select('A');
        await _settle();
        await h.cubit.submitModule();
        expect(h.repo.submitCalls, isEmpty);
        expect(h.module.submitError?.code, ErrorCodes.network);
        expect(h.module.submitting, isFalse);
      },
    );

    test(
      'MCK-01: module 1 submit opens the gap and clears the outbox',
      () async {
        final h = _harness();
        await h.startModule();
        h.cubit.select('A');
        await _settle();
        h.repo.submitResult = Success(h.gapStage());
        await h.cubit.submitModule();
        expect(h.gap.remaining, const Duration(seconds: 120));
        expect(h.pending.cleared, contains('attempt-1'));
      },
    );

    test('MCK-01: a started-module marker after submit is followed', () async {
      final h = _harness();
      await h.startModule();
      h.repo.submitResult = const Success(
        MockModuleStartedStage(groupId: fakeGroupId, moduleNo: 2),
      );
      h.repo.sessionResult = Success(h.moduleStage(moduleNo: 2));
      await h.cubit.submitModule();
      expect(h.module.module.moduleNo, 2);
      expect(h.repo.sessionCalls, hasLength(2));
    });

    test('MCK-01: module 2 submit loads the result', () async {
      final h = _harness();
      await h.startModule(h.moduleStage(moduleNo: 2));
      h.repo.submitResult = const Success(
        MockFinishedStage(groupId: fakeGroupId, resultId: 'r1'),
      );
      await h.cubit.submitModule();
      expect(h.finished.result, fakeResult);
    });

    test(
      'MCK-01: a result read failure keeps the run finished and retries',
      () async {
        final h = _harness();
        await h.startModule(h.moduleStage(moduleNo: 2));
        h.repo.submitResult = const Success(
          MockFinishedStage(groupId: fakeGroupId, resultId: 'r1'),
        );
        h.repo.resultResult = const Failure(AppError(ErrorCodes.network));
        await h.cubit.submitModule();
        expect(h.finished.result, isNull);
        expect(h.finished.resultError, const AppError(ErrorCodes.network));
        expect(h.finished.loading, isFalse);
        h.repo.resultResult = const Success(fakeResult);
        await h.cubit.retryResult();
        expect(h.finished.result, fakeResult);
        expect(h.finished.resultError, isNull);
        expect(h.repo.resultCalls, ['r1', 'r1']);
      },
    );
  });

  group('server fallbacks', () {
    for (final code in [ErrorCodes.deadlinePassed, ErrorCodes.invalidInput]) {
      test('MCK-01: submit $code falls back to session()', () async {
        final h = _harness();
        await h.startModule();
        h.repo.submitResult = Failure(AppError(code));
        h.repo.sessionResult = Success(h.gapStage());
        await h.cubit.submitModule();
        expect(h.repo.sessionCalls, hasLength(2));
        expect(h.cubit.state, isA<MockExamGap>());
        expect(h.repo.submitCalls, hasLength(1));
      });
    }

    test(
      'MCK-01: submit deadline_passed can land on the finished screen',
      () async {
        final h = _harness();
        await h.startModule(h.moduleStage(moduleNo: 2));
        h.repo.submitResult = const Failure(
          AppError(ErrorCodes.deadlinePassed),
        );
        h.repo.sessionResult = const Success(
          MockFinishedStage(groupId: fakeGroupId, resultId: 'r1'),
        );
        await h.cubit.submitModule();
        expect(h.finished.result, fakeResult);
      },
    );

    test('MCK-01: save deadline_passed follows the server stage', () async {
      final h = _harness();
      await h.startModule();
      h.repo.saveResult = const Failure(AppError(ErrorCodes.deadlinePassed));
      h.repo.sessionResult = Success(h.gapStage());
      h.cubit.select('A');
      await _settle();
      expect(h.cubit.state, isA<MockExamGap>());
      expect(h.pending.cleared, contains('attempt-1'));
    });

    test('MCK-01: save invalid_input follows the server stage', () async {
      final h = _harness();
      await h.startModule();
      h.repo.saveResult = const Failure(AppError(ErrorCodes.invalidInput));
      h.repo.sessionResult = Success(h.moduleStage(moduleNo: 2));
      h.cubit.select('A');
      await _settle();
      expect(h.module.module.moduleNo, 2);
      expect(h.repo.sessionCalls, hasLength(2));
    });

    test(
      'MCK-01: a transient save failure shows saveError and recovers',
      () async {
        final h = _harness();
        await h.startModule();
        h.repo.saveQueue.add(const Failure(AppError(ErrorCodes.network)));
        h.cubit.select('A');
        await _settle();
        expect(h.module.saveError, const AppError(ErrorCodes.network));
        h.tick(const Duration(seconds: 3));
        await _settle();
        expect(h.module.saveError, isNull);
        expect(h.repo.saves, hasLength(2));
      },
    );
  });

  group('gap', () {
    test(
      'MCK-01: the countdown ends with one session() call into module 2',
      () async {
        final h = _harness();
        h.repo.sessionQueue.addAll([
          Success(h.gapStage()),
          Success(h.moduleStage(moduleNo: 2)),
        ]);
        await h.cubit.start();
        expect(h.repo.sessionCalls, hasLength(1));
        h.tick(const Duration(seconds: 119));
        expect(h.gap.remaining, const Duration(seconds: 1));
        expect(h.repo.sessionCalls, hasLength(1));
        h.tick(const Duration(seconds: 2));
        await _settle();
        h
          ..tick()
          ..tick();
        await _settle();
        expect(h.repo.sessionCalls, hasLength(2));
        expect(h.module.module.moduleNo, 2);
        expect(h.repo.startModule2Calls, isEmpty);
      },
    );

    test('MCK-01: starting module 2 early calls start_mock_module2', () async {
      final h = _harness();
      await h.startModule(h.gapStage());
      h.repo.startModule2Result = Success(h.moduleStage(moduleNo: 2));
      await h.cubit.startModule2();
      expect(h.repo.startModule2Calls, [fakeGroupId]);
      expect(h.module.module.moduleNo, 2);
      expect(h.repo.sessionCalls, hasLength(1));
    });

    test('MCK-01: a double tap on start module 2 calls once', () async {
      final h = _harness();
      await h.startModule(h.gapStage());
      final gate = h.repo.startModule2Gate = Completer<void>();
      h.repo.startModule2Result = Success(h.moduleStage(moduleNo: 2));
      final first = h.cubit.startModule2();
      await _settle();
      expect(h.gap.startingModule2, isTrue);
      final second = h.cubit.startModule2();
      gate.complete();
      await Future.wait([first, second]);
      expect(h.repo.startModule2Calls, hasLength(1));
    });

    test(
      'MCK-01: a start module 2 failure keeps the gap and can retry',
      () async {
        final h = _harness();
        await h.startModule(h.gapStage());
        h.repo.startModule2Result = const Failure(
          AppError(ErrorCodes.rateLimited),
        );
        await h.cubit.startModule2();
        expect(h.gap.error, const AppError(ErrorCodes.rateLimited));
        expect(h.gap.startingModule2, isFalse);
        h.repo.startModule2Result = Success(h.moduleStage(moduleNo: 2));
        await h.cubit.startModule2();
        expect(h.module.module.moduleNo, 2);
      },
    );

    test(
      'MCK-01: leaving and re-starting during the gap lands on module 2',
      () async {
        final h = _harness();
        await h.startModule(h.gapStage());
        expect(h.cubit.state, isA<MockExamGap>());
        h.clock = h.clock.add(const Duration(minutes: 10));
        h.repo.sessionResult = Success(h.moduleStage(moduleNo: 2));
        await h.cubit.start();
        expect(h.module.module.moduleNo, 2);
        expect(h.module.remaining, const Duration(minutes: 35));
      },
    );

    test(
      'MCK-01: re-starting after the gap on a finished run shows the score',
      () async {
        final h = _harness();
        await h.startModule(h.gapStage());
        h.repo.sessionResult = const Success(
          MockFinishedStage(groupId: fakeGroupId, resultId: 'r1'),
        );
        await h.cubit.start();
        expect(h.finished.result, fakeResult);
      },
    );
  });

  group('lifecycle', () {
    test('MCK-01: closing during a submit does not emit or throw', () async {
      final h = _harness();
      await h.startModule();
      final gate = h.repo.submitGate = Completer<void>();
      h.repo.submitResult = Success(h.gapStage());
      final pending = h.cubit.submitModule();
      await _settle();
      await h.cubit.close();
      gate.complete();
      await pending;
      expect(h.module.submitting, isTrue);
    });

    test('MCK-01: closing during start does not emit', () async {
      final h = _harness();
      final gate = h.repo.sessionGate = Completer<void>();
      h.repo.sessionResult = Success(h.moduleStage());
      final pending = h.cubit.start();
      await h.cubit.close();
      gate.complete();
      await pending;
      expect(h.cubit.state, isA<MockExamLoading>());
    });

    test('MCK-01: closing during the result read does not emit', () async {
      final h = _harness();
      await h.startModule(h.moduleStage(moduleNo: 2));
      h.repo.submitResult = const Success(
        MockFinishedStage(groupId: fakeGroupId, resultId: 'r1'),
      );
      await h.cubit.submitModule();
      h.repo.resultResult = const Failure(AppError(ErrorCodes.network));
      final retry = h.cubit.retryResult();
      await h.cubit.close();
      await retry;
    });

    test(
      'MCK-01: ticks after closing are ignored and the ticker is released',
      () async {
        final h = _harness();
        await h.startModule();
        expect(h.ticks.hasListener, isTrue);
        await h.cubit.close();
        expect(h.ticks.hasListener, isFalse);
      },
    );

    test('MCK-01: a new start replaces the previous run', () async {
      final h = _harness();
      await h.startModule();
      h.cubit.select('A');
      await _settle();
      h.repo.sessionResult = Success(h.moduleStage(moduleNo: 2));
      await h.cubit.start();
      expect(h.module.module.moduleNo, 2);
      expect(h.ticks.hasListener, isTrue);
    });
  });
}
