import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/attempts/save_outcome.dart';
import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/homework/domain/entities/homework.dart';
import 'package:sat_east_client/features/homework/domain/repositories/homework_repository.dart';
import 'package:sat_east_client/features/homework/presentation/cubit/homework_cubit.dart';
import 'package:sat_east_client/features/homework/presentation/cubit/homework_state.dart';

import '../../../support/in_memory_pending_answers.dart';
import '../homework_fixture.dart';

class _Repo implements HomeworkRepository {
  Result<HomeworkReport> submitResult = const Success(homeworkReport);
  Future<Result<SaveOutcome>> Function(int call)? onSave;
  final saves = <({String id, String? answer, bool marked, int seq})>[];

  @override
  Future<Result<HomeworkSession>> start(String topicId) async =>
      const Success(homeworkSession);

  @override
  Future<Result<HomeworkReport>> submit(String attemptId) async => submitResult;

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
    saves.add((id: questionId, answer: answer, marked: marked, seq: clientSeq));
    return onSave?.call(saves.length) ?? const Success(SaveOutcome.saved);
  }
}

Future<void> _settle() async {
  for (var i = 0; i < 30; i++) {
    await Future<void>.value();
  }
}

const _network = Failure<SaveOutcome>(AppError(ErrorCodes.network));

void main() {
  late _Repo repo;
  late InMemoryPendingAnswers pending;
  final cubits = <HomeworkCubit>[];

  HomeworkCubit build() {
    final cubit = HomeworkCubit(
      repo,
      () => DateTime.utc(2026),
      (_) => const Stream<void>.empty(),
      pending,
    );
    cubits.add(cubit);
    return cubit;
  }

  setUp(() {
    repo = _Repo();
    pending = InMemoryPendingAnswers();
  });
  tearDown(() async {
    for (final cubit in cubits) {
      await cubit.close();
    }
    cubits.clear();
  });

  test('PRC-05: an answer is stored, then removed once saved', () async {
    final flight = Completer<Result<SaveOutcome>>();
    repo.onSave = (_) => flight.future;
    final cubit = build();
    await cubit.start('t1');
    cubit.select('A');
    final entry = pending.forAttempt('hw1')['q1']!;
    expect(entry.answer, 'A');
    expect(entry.marked, isTrue);
    expect(entry.rev, 1);
    flight.complete(const Success(SaveOutcome.saved));
    await _settle();
    expect(pending.forAttempt('hw1'), isEmpty);
  });

  test('PRC-05: an unsaved answer survives a reload and is re-sent', () async {
    repo.onSave = (_) async => _network;
    final first = build();
    await first.start('t1');
    first
      ..goTo(1)
      ..sprChanged('.5')
      ..toggleMark();
    await _settle();
    expect(pending.forAttempt('hw1')['q2']!.answer, '.5');
    await first.close();

    repo
      ..saves.clear()
      ..onSave = null;
    final reloaded = build();
    await reloaded.start('t1');
    final state = reloaded.state as HomeworkRunning;
    expect(state.answers, {'q1': 'B', 'q2': '.5'});
    expect(state.marked, {'q1', 'q2'});
    await _settle();
    final resent = repo.saves.single;
    expect(resent.id, 'q2');
    expect(resent.answer, '.5');
    expect(resent.marked, isTrue);
    expect(resent.seq, 10);
    expect(pending.forAttempt('hw1'), isEmpty);
  });

  test('PRC-05: a local snapshot overrides the server mark', () async {
    pending.put('hw1', 'q1', answer: 'A', marked: false, timeMs: 0);
    final cubit = build();
    await cubit.start('t1');
    final state = cubit.state as HomeworkRunning;
    expect(state.answers, {'q1': 'A'});
    expect(state.marked, isEmpty);
    await _settle();
    expect(repo.saves.single.answer, 'A');
  });

  test('PRC-05: a stale ack does not remove a newer edit', () async {
    final first = Completer<Result<SaveOutcome>>();
    final second = Completer<Result<SaveOutcome>>();
    repo.onSave = (call) => call == 1 ? first.future : second.future;
    final cubit = build();
    await cubit.start('t1');
    cubit
      ..select('A')
      ..select('B');
    first.complete(const Success(SaveOutcome.saved));
    await _settle();
    expect(repo.saves, hasLength(2));
    expect(pending.forAttempt('hw1')['q1']!.answer, 'B');
    second.complete(const Success(SaveOutcome.saved));
    await _settle();
    expect(pending.forAttempt('hw1'), isEmpty);
  });

  test('PRC-05: a successful submit clears the attempt', () async {
    final cubit = build();
    await cubit.start('t1');
    cubit.select('A');
    await cubit.submit();
    expect(cubit.state, isA<HomeworkSubmitted>());
    expect(pending.cleared, ['hw1']);
  });

  test('PRC-05: a failed submit keeps the attempt entries', () async {
    repo
      ..onSave = ((_) async => _network)
      ..submitResult = const Failure(AppError(ErrorCodes.network));
    final cubit = build();
    await cubit.start('t1');
    cubit.select('A');
    await cubit.submit();
    expect(pending.cleared, isEmpty);
    expect(pending.forAttempt('hw1'), isNotEmpty);
  });

  test('PRC-05: deadline_passed clears the attempt', () async {
    repo.onSave = (_) async =>
        const Failure(AppError(ErrorCodes.deadlinePassed));
    final cubit = build();
    await cubit.start('t1');
    cubit.select('A');
    await _settle();
    expect(pending.cleared, contains('hw1'));
    expect(pending.forAttempt('hw1'), isEmpty);
  });
}
