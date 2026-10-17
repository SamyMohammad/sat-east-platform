part of 'quiz_cubit_test.dart';

void _clockCases() {
  group('QuizCubit', () {
    late _Harness h;
    setUp(() => h = _Harness());
    tearDown(() => h.close());

    test(
      'PRC-03: countdown follows elapsed clock time rather than tick count',
      () async {
        await h.cubit.start('topic');
        await h.tick(const Duration(seconds: 17));
        expect(h.running.remaining, const Duration(minutes: 19, seconds: 43));
        await h.tick(Duration.zero);
        expect(h.running.remaining, const Duration(minutes: 19, seconds: 43));
      },
    );

    for (final skew in [-10, 10]) {
      test(
        'PRC-03: server offset corrects a $skew minute device skew',
        () async {
          h.clock = h.clock.add(Duration(minutes: skew));
          await h.cubit.start('topic');
          expect(h.running.remaining, const Duration(minutes: 20));
          await h.tick(const Duration(seconds: 4));
          expect(h.running.remaining, const Duration(minutes: 19, seconds: 56));
        },
      );
    }

    test(
      'PRC-03: timer visibility toggles without stopping countdown',
      () async {
        await h.cubit.start('topic');
        h.cubit.toggleTimer();
        expect(h.running.timerHidden, isTrue);
        await h.tick(const Duration(seconds: 1));
        expect(h.running.remaining, const Duration(minutes: 19, seconds: 59));
        h.cubit.toggleTimer();
        expect(h.running.timerHidden, isFalse);
        expect(h.repo.saves, isEmpty);
      },
    );

    test('PRC-03: zero remaining automatically submits exactly once', () async {
      await h.cubit.start('topic');
      await h.tick(const Duration(minutes: 20));
      await h.tick(const Duration(seconds: 1));
      await h.cubit.timeUp();
      expect(h.repo.submitted, ['attempt']);
      expect(h.cubit.state, const QuizSubmitted(_report));
    });

    test('PRC-03: timeUp exposes zero remaining during submission', () async {
      final report = Completer<Result<QuizReport>>();
      h.repo.onSubmit = (_) => report.future;
      await h.cubit.start('topic');
      final pending = h.cubit.timeUp();
      await _settle();
      expect(h.running.remaining, Duration.zero);
      expect(h.running.submitting, isTrue);
      report.complete(const Success(_report));
      await pending;
    });

    test(
      'PRC-03: overdue server session automatically submits on resume',
      () async {
        h.repo.session = _session(remaining: const Duration(seconds: -1));
        await h.cubit.start('topic');
        await _settle();
        expect(h.repo.submitted, ['attempt']);
        expect(h.cubit.state, const QuizSubmitted(_report));
      },
    );

    test(
      'PRC-03: time-up waits for an in-flight save even when offline',
      () async {
        final save = Completer<Result<SaveOutcome>>();
        h.repo.onSave = (_) => save.future;
        await h.cubit.start('topic');
        h.cubit.select('B');
        await h.tick(const Duration(minutes: 20));
        await h.tick(const Duration(seconds: 2));
        expect(h.running.submitting, isTrue);
        expect(h.repo.submitted, isEmpty);
        save.complete(const Failure(_network));
        await _settle();
        expect(h.repo.submitted, ['attempt']);
        expect(h.cubit.state, const QuizSubmitted(_report));
        await h.tick(const Duration(seconds: 10));
        expect(h.repo.saves, hasLength(2));
        expect(h.repo.submitted, hasLength(1));
      },
    );

    test(
      'PRC-03: deadline_passed save triggers submit without a deadlock',
      () async {
        h.repo.onSave = (_) async =>
            const Failure(AppError(ErrorCodes.deadlinePassed));
        await h.cubit.start('topic');
        h.cubit.select('A');
        await _settle();
        expect(h.repo.submitted, ['attempt']);
        expect(h.cubit.state, const QuizSubmitted(_report));
      },
    );

    test('PRC-03: failed automatic submit waits for a manual retry', () async {
      h.repo.submitResult = const Failure(_network);
      await h.cubit.start('topic');
      await h.tick(const Duration(minutes: 20));
      expect(h.running.submitError, _network);
      await h.tick(const Duration(seconds: 5));
      await h.cubit.timeUp();
      expect(h.repo.submitted, hasLength(1));
      h.repo.submitResult = const Success(_report);
      await h.cubit.submit();
      expect(h.repo.submitted, hasLength(2));
      expect(h.cubit.state, const QuizSubmitted(_report));
    });
  });
}
