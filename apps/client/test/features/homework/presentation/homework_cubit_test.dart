import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/attempts/save_outcome.dart';
import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/homework/domain/entities/homework.dart';
import 'package:sat_east_client/features/homework/domain/repositories/homework_repository.dart';
import 'package:sat_east_client/features/homework/presentation/cubit/homework_cubit.dart';
import 'package:sat_east_client/features/homework/presentation/cubit/homework_state.dart';
import 'package:sat_east_client/features/homework/presentation/homework_copy.dart';

import '../homework_fixture.dart';

class _Repo implements HomeworkRepository {
  Result<HomeworkSession> startResult = const Success(homeworkSession);
  Result<HomeworkReport> submitResult = const Success(homeworkReport);
  final saves =
      <
        ({
          String? answer,
          bool marked,
          List<String> eliminated,
          int seq,
          String id,
        })
      >[];
  final submitted = <String>[];
  Completer<Result<SaveOutcome>>? pending;
  @override
  Future<Result<HomeworkSession>> start(String topicId) async => startResult;
  @override
  Future<Result<HomeworkReport>> submit(String attemptId) async {
    submitted.add(attemptId);
    return submitResult;
  }

  @override
  Future<Result<SaveOutcome>> save({
    required String attemptId,
    required String questionId,
    required int timeMs,
    required bool marked,
    required List<String> eliminated,
    required int clientSeq,
    String? answer,
  }) async {
    saves.add((
      answer: answer,
      marked: marked,
      eliminated: eliminated,
      seq: clientSeq,
      id: questionId,
    ));
    return pending?.future ?? const Success(SaveOutcome.saved);
  }
}

void main() {
  late _Repo repo;
  late HomeworkCubit cubit;
  setUp(() {
    repo = _Repo();
    cubit = HomeworkCubit(
      repo,
      () => DateTime.utc(2026),
      (_) => const Stream<void>.empty(),
    );
  });
  tearDown(() => cubit.close());
  test('PRC-05: resume restores answers and marks', () async {
    await cubit.start('t1');
    final state = cubit.state as HomeworkRunning;
    expect(state.answers, {'q1': 'B'});
    expect(state.marked, {'q1'});
    expect(state.index, 0);
  });
  test(
    'PRC-05: select/mark/eliminate/restore enqueue increasing saves',
    () async {
      await cubit.start('t1');
      cubit.select('A');
      await Future<void>.delayed(Duration.zero);
      cubit.toggleMark();
      await Future<void>.delayed(Duration.zero);
      cubit.eliminate('B');
      await Future<void>.delayed(Duration.zero);
      expect(repo.saves.last.eliminated, ['B']);
      cubit.restore('B');
      await Future<void>.delayed(Duration.zero);
      expect(repo.saves.last.eliminated, isEmpty);
      expect(repo.saves.map((s) => s.seq), [10, 11, 12, 13]);
      expect(repo.saves.first.answer, 'A');
      expect(repo.saves[1].marked, isFalse);
    },
  );
  test('PRC-05: navigation bounds and SPR edits', () async {
    await cubit.start('t1');
    cubit.goTo(-1);
    expect((cubit.state as HomeworkRunning).index, 0);
    cubit
      ..goTo(1)
      ..sprChanged('.5');
    await Future<void>.delayed(Duration.zero);
    expect(repo.saves.single.id, 'q2');
    expect(repo.saves.single.answer, '.5');
    cubit.goTo(9);
    expect((cubit.state as HomeworkRunning).index, 1);
  });
  test(
    'PRC-02: submit awaits saves and prevents editing while flushing',
    () async {
      await cubit.start('t1');
      final flight = Completer<Result<SaveOutcome>>();
      repo.pending = flight;
      cubit.select('A');
      final submitting = cubit.submit();
      cubit.select('B');
      expect(repo.submitted, isEmpty);
      expect((cubit.state as HomeworkRunning).submitting, isTrue);
      flight.complete(const Success(SaveOutcome.saved));
      await submitting;
      expect(repo.submitted, ['hw1']);
      expect(cubit.state, const HomeworkSubmitted(homeworkReport));
      expect(repo.saves.single.answer, 'A');
    },
  );
  test('PRC-02: failed pending saves prevent submit', () async {
    await cubit.start('t1');
    final flight = Completer<Result<SaveOutcome>>();
    repo.pending = flight;
    cubit.select('A');
    flight.complete(const Failure(AppError(ErrorCodes.network)));
    await Future<void>.delayed(Duration.zero);
    await cubit.submit();
    expect(repo.submitted, isEmpty);
    expect((cubit.state as HomeworkRunning).submitError, isNotNull);
  });
  test('PRC-02: stopped saves still recover the submitted report', () async {
    await cubit.start('t1');
    final states = <HomeworkState>[];
    final subscription = cubit.stream.listen(states.add);
    addTearDown(subscription.cancel);
    final flight = Completer<Result<SaveOutcome>>();
    repo.pending = flight;
    cubit.select('A');
    flight.complete(const Failure(AppError(ErrorCodes.invalidInput)));
    await Future<void>.delayed(Duration.zero);
    expect(
      (cubit.state as HomeworkRunning).saveError,
      const AppError(ErrorCodes.invalidInput),
    );

    await cubit.submit();
    await Future<void>.delayed(Duration.zero);

    expect(repo.submitted, ['hw1']);
    expect(repo.saves, hasLength(1));
    expect(cubit.state, const HomeworkSubmitted(homeworkReport));
    expect(states.last, const HomeworkSubmitted(homeworkReport));
  });
  test('PRC-02: errors preserve codes and map to English copy', () async {
    repo.startResult = const Failure(AppError(ErrorCodes.practiceNeeded));
    await cubit.start('t1');
    expect(
      cubit.state,
      const HomeworkFailed(AppError(ErrorCodes.practiceNeeded)),
    );
    repo.startResult = const Success(homeworkSession);
    await cubit.start('t1');
    repo.submitResult = const Failure(AppError(ErrorCodes.network));
    await cubit.submit();
    final state = cubit.state as HomeworkRunning;
    expect(state.submitting, isFalse);
    expect(
      HomeworkCopy.errorBody(state.submitError!.code),
      contains('connection'),
    );
  });
  test(
    'PRC-05: close flushes the latest queued edit before disposal',
    () async {
      await cubit.start('t1');
      final flight = Completer<Result<SaveOutcome>>();
      repo.pending = flight;
      cubit
        ..select('A')
        ..select('B');
      await cubit.close();
      expect(repo.saves.map((s) => s.seq), [10, 11]);
      expect(repo.saves.last.answer, 'B');
      flight.complete(const Success(SaveOutcome.saved));
      await Future<void>.delayed(Duration.zero);
      expect(cubit.isClosed, isTrue);
    },
  );
  test('PRC-05: retrySave clears a transient failure', () async {
    await cubit.start('t1');
    final flight = Completer<Result<SaveOutcome>>();
    repo.pending = flight;
    cubit.select('A');
    flight.complete(const Failure(AppError(ErrorCodes.network)));
    await Future<void>.delayed(Duration.zero);
    expect((cubit.state as HomeworkRunning).saveError, isNotNull);
    repo.pending = null;
    await cubit.retrySave();
    expect((cubit.state as HomeworkRunning).saveError, isNull);
    expect((cubit.state as HomeworkRunning).saving, isFalse);
    expect(repo.saves.map((s) => s.seq), [10, 11]);
  });
  test(
    'PRC-05: retrySave retains failure when the network stays down',
    () async {
      await cubit.start('t1');
      final flight = Completer<Result<SaveOutcome>>();
      repo.pending = flight;
      cubit.select('A');
      flight.complete(const Failure(AppError(ErrorCodes.network)));
      await Future<void>.delayed(Duration.zero);
      await cubit.retrySave();
      expect(
        (cubit.state as HomeworkRunning).saveError,
        const AppError(ErrorCodes.network),
      );
      expect(repo.submitted, isEmpty);
    },
  );
  test(
    'PRC-05: submit waits for every save in an active manual retry',
    () async {
      await cubit.start('t1');
      final failed = Completer<Result<SaveOutcome>>();
      repo.pending = failed;
      cubit
        ..select('A')
        ..goTo(1)
        ..sprChanged('.5');
      failed.complete(const Failure(AppError(ErrorCodes.network)));
      await Future<void>.delayed(Duration.zero);
      final first = Completer<Result<SaveOutcome>>();
      final second = Completer<Result<SaveOutcome>>();
      repo.pending = first;
      final retrying = cubit.retrySave();
      final submitting = cubit.submit();
      repo.pending = second;
      first.complete(const Success(SaveOutcome.saved));
      await Future<void>.delayed(Duration.zero);
      expect(repo.submitted, isEmpty);
      second.complete(const Success(SaveOutcome.saved));
      await retrying;
      await submitting;
      expect(repo.submitted, ['hw1']);
    },
  );
  test('PRC-02: closed cubit ignores late start response', () async {
    await cubit.close();
    await cubit.start('t1');
    expect(cubit.isClosed, isTrue);
  });
}
