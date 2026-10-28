part of 'quiz_cubit_test.dart';

void _submitCases() {
  group('QuizCubit', () {
    late _Harness h;
    setUp(() => h = _Harness());
    tearDown(() => h.close());

    test(
      'PRC-03: elapsed deadline submits despite failed manual flush '
      'without tick',
      () async {
        final first = Completer<Result<SaveOutcome>>();
        final finalSave = Completer<Result<SaveOutcome>>();
        h.repo.onSave = (_) =>
            h.repo.saves.length == 1 ? first.future : finalSave.future;
        await h.cubit.start('topic');
        h.cubit.select('A');
        h.cubit.select('B');
        final pending = h.cubit.submit();
        first.complete(const Success(SaveOutcome.saved));
        await _settle();
        expect(h.repo.saves, hasLength(2));
        h.clock = h.clock.add(const Duration(minutes: 21));
        finalSave.complete(const Failure(_network));
        await pending;
        expect(h.repo.submitted, ['attempt']);
        expect(h.cubit.state, const QuizSubmitted(_report));
      },
    );

    test('PRC-03: manual submit emits the exact server report', () async {
      await h.cubit.start('topic');
      await h.cubit.submit();
      expect(h.repo.submitted, ['attempt']);
      expect(h.cubit.state, const QuizSubmitted(_report));
    });

    test(
      'PRC-03: concurrent manual and automatic submits call server once',
      () async {
        final report = Completer<Result<QuizReport>>();
        h.repo.onSubmit = (_) => report.future;
        await h.cubit.start('topic');
        final manual = h.cubit.submit();
        final duplicate = h.cubit.submit();
        final automatic = h.cubit.timeUp();
        await _settle();
        expect(h.repo.submitted, ['attempt']);
        report.complete(const Success(_report));
        await Future.wait([manual, duplicate, automatic]);
        expect(h.cubit.state, const QuizSubmitted(_report));
      },
    );

    test(
      'PRC-03: submit waits for the active save before calling server',
      () async {
        final save = Completer<Result<SaveOutcome>>();
        h.repo.onSave = (_) => save.future;
        await h.cubit.start('topic');
        h.cubit.select('A');
        final pending = h.cubit.submit();
        await _settle();
        expect(h.repo.submitted, isEmpty);
        expect(h.running.submitting, isTrue);
        save.complete(const Success(SaveOutcome.saved));
        await pending;
        expect(h.repo.submitted, ['attempt']);
      },
    );

    test(
      'PRC-03: submit remains single while ticker cancellation is pending',
      () async {
        final cancelling = Completer<void>();
        final cancelled = Completer<void>();
        final ticker = StreamController<void>(
          onCancel: () {
            cancelling.complete();
            return cancelled.future;
          },
        );
        final repo = _Repository();
        final cubit = QuizCubit(repo, () => h.clock, (_) => ticker.stream);
        addTearDown(() async {
          if (!cancelled.isCompleted) cancelled.complete();
          await cubit.close();
          await ticker.close();
        });
        await cubit.start('topic');
        final first = cubit.submit();
        await cancelling.future;
        final second = cubit.submit();
        final automatic = cubit.timeUp();
        try {
          await _settle();
          expect(repo.submitted, hasLength(1));
        } finally {
          cancelled.complete();
          await Future.wait([first, second, automatic]);
        }
        expect(cubit.state, const QuizSubmitted(_report));
      },
    );

    test(
      'PRC-03: submit drains latest queued changes before submitting',
      () async {
        final first = Completer<Result<SaveOutcome>>();
        final second = Completer<Result<SaveOutcome>>();
        h.repo.onSave = (_) =>
            h.repo.saves.length == 1 ? first.future : second.future;
        await h.cubit.start('topic');
        h.cubit.select('A');
        h.cubit.select('B');
        h.cubit.toggleMark();
        final pending = h.cubit.submit();
        first.complete(const Success(SaveOutcome.saved));
        await _settle();
        expect(h.repo.saves, hasLength(2));
        expect(h.repo.saves.last.answer, 'B');
        expect(h.repo.saves.last.marked, isTrue);
        expect(h.repo.submitted, isEmpty);
        second.complete(const Success(SaveOutcome.saved));
        await pending;
        expect(h.repo.submitted, ['attempt']);
      },
    );

    for (final retryFails in [false, true]) {
      test(
        'PRC-03: submit flushes a failed in-flight answer once '
        'when the final save ${retryFails ? 'fails' : 'succeeds'}',
        () async {
          final first = Completer<Result<SaveOutcome>>();
          final second = Completer<Result<SaveOutcome>>();
          h.repo.onSave = (_) =>
              h.repo.saves.length == 1 ? first.future : second.future;
          await h.cubit.start('topic');
          h.cubit.select('A');
          final pending = retryFails ? h.cubit.timeUp() : h.cubit.submit();
          first.complete(const Failure(_network));
          try {
            await _settle();
            expect(h.repo.saves, hasLength(2));
            expect(h.repo.saves.last.questionId, 'mcq');
            expect(h.repo.saves.last.answer, 'A');
            expect(h.repo.saves.last.clientSeq, 2);
            expect(h.repo.submitted, isEmpty);
          } finally {
            second.complete(
              retryFails
                  ? const Failure(_network)
                  : const Success(SaveOutcome.saved),
            );
            await pending;
          }
          expect(h.repo.submitted, ['attempt']);
          await h.tick(const Duration(seconds: 10));
          expect(h.repo.saves, hasLength(2));
          expect(h.repo.submitted, hasLength(1));
        },
      );
    }

    test(
      'PRC-03: time-up submit proceeds after each queued save fails once',
      () async {
        final first = Completer<Result<SaveOutcome>>();
        h.repo.onSave = (_) => h.repo.saves.length == 1
            ? first.future
            : Future.value(const Failure(_network));
        await h.cubit.start('topic');
        h.cubit.select('A');
        h.cubit.select('B');
        h.cubit.next();
        h.cubit.sprChanged('3');
        final pending = h.cubit.timeUp();
        first.complete(const Failure(_network));
        await pending;
        expect(h.repo.saves, hasLength(3));
        expect(h.repo.saves.map((s) => s.clientSeq), [1, 2, 3]);
        expect(h.repo.submitted, ['attempt']);
      },
    );

    for (final includeSecondQuestion in [false, true]) {
      test('PRC-03: manual submit blocks on dirty answers and allows retry '
          '(second question succeeds: $includeSecondQuestion)', () async {
        final first = Completer<Result<SaveOutcome>>();
        h.repo.onSave = (_) => h.repo.saves.length == 1
            ? first.future
            : Future.value(
                includeSecondQuestion && h.repo.saves.last.questionId == 'spr'
                    ? const Success(SaveOutcome.saved)
                    : const Failure(_network),
              );
        await h.cubit.start('topic');
        h.cubit.select('A');
        h.cubit.select('B');
        if (includeSecondQuestion) {
          h.cubit.next();
          h.cubit.sprChanged('3');
        }
        final pending = h.cubit.submit();
        first.complete(const Failure(_network));
        await pending;
        expect(h.repo.saves, hasLength(includeSecondQuestion ? 3 : 2));
        expect(h.repo.saves[1].answer, 'B');
        expect(h.repo.submitted, isEmpty);
        expect(h.running.submitting, isFalse);
        expect(h.running.submitError, _network);
        expect(h.running.saveError, _network);
        expect(h.running.answers['mcq'], 'B');
        h.repo.onSave = (_) async => const Success(SaveOutcome.saved);
        await h.cubit.submit();
        expect(h.repo.saves, hasLength(includeSecondQuestion ? 4 : 3));
        expect(h.repo.saves.last.answer, 'B');
        expect(h.repo.saves.last.clientSeq, includeSecondQuestion ? 4 : 3);
        expect(h.repo.submitted, ['attempt']);
        expect(h.cubit.state, const QuizSubmitted(_report));
      });
    }

    test(
      'PRC-03: submitting freezes answer changes, marks and navigation',
      () async {
        final report = Completer<Result<QuizReport>>();
        h.repo.onSubmit = (_) => report.future;
        await h.cubit.start('topic');
        final pending = h.cubit.submit();
        h.cubit.select('B');
        h.cubit.sprChanged('3');
        h.cubit.toggleMark();
        h.cubit.goTo(1);
        h.cubit.next();
        h.cubit.prev();
        expect(h.running.index, 0);
        expect(h.running.answers, isEmpty);
        expect(h.running.marked, isEmpty);
        expect(h.repo.saves, isEmpty);
        await h.tick(const Duration(seconds: 3));
        expect(h.running.remaining, const Duration(minutes: 19, seconds: 57));
        report.complete(const Success(_report));
        await pending;
      },
    );

    test(
      'PRC-03: submit failure keeps answers and allows manual retry',
      () async {
        h.repo.submitResult = const Failure(_network);
        await h.cubit.start('topic');
        h.cubit.select('A');
        await _settle();
        await h.cubit.submit();
        expect(h.running.submitting, isFalse);
        expect(h.running.submitError, _network);
        expect(h.running.answers, {'mcq': 'A'});
        h.repo.submitResult = const Success(_report);
        await h.cubit.submit();
        expect(h.repo.submitted, ['attempt', 'attempt']);
        expect(h.cubit.state, const QuizSubmitted(_report));
      },
    );

    test(
      'PRC-03: submission wait time is excluded from question time on retry',
      () async {
        final report = Completer<Result<QuizReport>>();
        h.repo.onSubmit = (_) => report.future;
        await h.cubit.start('topic');
        await h.tick(const Duration(seconds: 2));
        final pending = h.cubit.submit();
        await h.tick(const Duration(seconds: 8));
        report.complete(const Failure(_network));
        await pending;
        await h.tick(const Duration(seconds: 3));
        h.cubit.select('A');
        await _settle();
        expect(h.repo.saves.single.timeMs, 5000);
      },
    );

    test(
      'PRC-03: submit preserves a failed report including retake metadata',
      () async {
        final report = QuizReport(
          attemptId: 'a1',
          scoreRaw: 8,
          scoreTotal: 12,
          scorePct: 66.67,
          passMark: 75,
          passed: false,
          nextTopic: null,
          retakeAt: DateTime.utc(2026, 10, 18),
        );
        h.repo.submitResult = Success(report);
        await h.cubit.start('topic');
        await h.cubit.submit();
        expect(h.cubit.state, QuizSubmitted(report));
      },
    );
  });
}
