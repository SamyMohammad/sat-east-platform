part of 'quiz_cubit_test.dart';

void _outboxCases() {
  group('QuizCubit outbox', () {
    late _Harness h;
    late InMemoryPendingAnswers pending;
    setUp(() {
      pending = InMemoryPendingAnswers();
      h = _Harness(pending: pending);
    });
    tearDown(() => h.close());

    test('PRC-03: an answer is stored, then removed once saved', () async {
      final flight = Completer<Result<SaveOutcome>>();
      h.repo.onSave = (_) => flight.future;
      await h.cubit.start('topic');
      h.cubit.select('A');
      final entry = pending.forAttempt('attempt')['mcq']!;
      expect(entry.answer, 'A');
      expect(entry.marked, isFalse);
      expect(entry.rev, 1);
      flight.complete(const Success(SaveOutcome.saved));
      await _settle();
      expect(pending.forAttempt('attempt'), isEmpty);
    });

    test('PRC-03: a mark change is stored with the current answer', () async {
      h.repo.onSave = (_) async => const Failure(_network);
      await h.cubit.start('topic');
      h.cubit.select('A');
      h.cubit.toggleMark();
      final entry = pending.forAttempt('attempt')['mcq']!;
      expect(entry.answer, 'A');
      expect(entry.marked, isTrue);
      expect(entry.rev, 2);
    });

    test(
      'PRC-03: an unsaved answer survives a reload and is re-sent',
      () async {
        h.repo.onSave = (_) async => const Failure(_network);
        await h.cubit.start('topic');
        h.cubit.select('A');
        h.cubit.toggleMark();
        await _settle();
        expect(pending.forAttempt('attempt'), isNotEmpty);
        await h.cubit.close();

        final reloaded = _Harness(pending: pending);
        addTearDown(reloaded.close);
        reloaded.repo.session = _session(clientSeq: 4);
        await reloaded.cubit.start('topic');
        expect(reloaded.running.answers, {'mcq': 'A'});
        expect(reloaded.running.marked, {'mcq'});
        await _settle();
        final resent = reloaded.repo.saves.single;
        expect(resent.questionId, 'mcq');
        expect(resent.answer, 'A');
        expect(resent.marked, isTrue);
        expect(resent.clientSeq, 5);
        expect(pending.forAttempt('attempt'), isEmpty);
      },
    );

    test(
      'PRC-03: a local snapshot overrides the server answer and mark',
      () async {
        pending.put('attempt', 'mcq', answer: 'A', marked: false, timeMs: 0);
        h.repo.session = _session(
          answers: const {'mcq': SavedAnswer(answer: 'B', marked: true)},
          clientSeq: 2,
        );
        await h.cubit.start('topic');
        expect(h.running.answers, {'mcq': 'A'});
        expect(h.running.marked, isEmpty);
        await _settle();
        expect(h.repo.saves.single.answer, 'A');
        expect(h.repo.saves.single.marked, isFalse);
      },
    );

    test('PRC-03: a re-sent save keeps the stored time spent', () async {
      pending.put('attempt', 'mcq', answer: 'A', marked: false, timeMs: 9000);
      h.repo.session = _session(clientSeq: 2);
      await h.cubit.start('topic');
      await _settle();
      expect(h.repo.saves.single.timeMs, greaterThanOrEqualTo(9000));
    });

    test('PRC-03: entries of other attempts are ignored on resume', () async {
      pending.put('other', 'mcq', answer: 'A', marked: true, timeMs: 0);
      await h.cubit.start('topic');
      expect(h.running.answers, isEmpty);
      await _settle();
      expect(h.repo.saves, isEmpty);
      expect(pending.forAttempt('other'), hasLength(1));
    });

    test('PRC-03: a stale ack does not remove a newer edit', () async {
      final first = Completer<Result<SaveOutcome>>();
      final second = Completer<Result<SaveOutcome>>();
      h.repo.onSave = (_) =>
          h.repo.saves.length == 1 ? first.future : second.future;
      await h.cubit.start('topic');
      h.cubit.select('A');
      h.cubit.select('B');
      first.complete(const Success(SaveOutcome.saved));
      await _settle();
      expect(h.repo.saves, hasLength(2));
      expect(pending.forAttempt('attempt')['mcq']!.answer, 'B');
      second.complete(const Success(SaveOutcome.saved));
      await _settle();
      expect(pending.forAttempt('attempt'), isEmpty);
    });

    test('PRC-03: a successful submit clears the attempt', () async {
      await h.cubit.start('topic');
      h.cubit.select('A');
      await h.cubit.submit();
      expect(h.cubit.state, isA<QuizSubmitted>());
      expect(pending.cleared, ['attempt']);
    });

    test('PRC-03: a failed submit keeps the attempt entries', () async {
      h.repo.onSave = (_) async => const Failure(_network);
      h.repo.submitResult = const Failure(_network);
      await h.cubit.start('topic');
      h.cubit.select('A');
      await h.cubit.submit();
      expect(pending.cleared, isEmpty);
      expect(pending.forAttempt('attempt'), isNotEmpty);
    });

    test('PRC-03: deadline_passed clears the attempt', () async {
      h.repo.onSave = (_) async =>
          const Failure(AppError(ErrorCodes.deadlinePassed));
      h.repo.submitResult = const Failure(_network);
      await h.cubit.start('topic');
      h.cubit.select('A');
      await _settle();
      expect(pending.cleared, contains('attempt'));
      expect(pending.forAttempt('attempt'), isEmpty);
    });
  });
}
