part of 'quiz_cubit_test.dart';

void _lifecycleCases() {
  group('QuizCubit', () {
    late _Harness h;
    setUp(() => h = _Harness());
    tearDown(() => h.close());

    test(
      'PRC-03: navigation respects bounds and preserves answers and marks',
      () async {
        await h.cubit.start('topic');
        h.cubit.prev();
        h.cubit.goTo(-1);
        h.cubit.goTo(2);
        expect(h.running.index, 0);
        h.cubit.select('B');
        h.cubit.toggleMark();
        h.cubit.goTo(1);
        h.cubit.next();
        expect(h.running.index, 1);
        h.cubit.prev();
        expect(h.running.index, 0);
        expect(h.running.answers['mcq'], 'B');
        expect(h.running.marked, {'mcq'});
      },
    );

    test('PRC-03: methods outside a running quiz are harmless', () async {
      h.cubit.select('A');
      h.cubit.sprChanged('1');
      h.cubit.toggleMark();
      h.cubit.goTo(1);
      h.cubit.next();
      h.cubit.prev();
      h.cubit.toggleTimer();
      await h.cubit.submit();
      await h.cubit.timeUp();
      expect(h.repo.saves, isEmpty);
      expect(h.repo.submitted, isEmpty);
    });

    test('PRC-03: close cancels the ticker and pending retry', () async {
      h.repo.onSave = (_) async => const Failure(_network);
      await h.cubit.start('topic');
      expect(h.ticks.hasListener, isTrue);
      h.cubit.select('A');
      await _settle();
      final state = h.cubit.state;
      await h.cubit.close();
      expect(h.ticks.hasListener, isFalse);
      await h.tick(const Duration(seconds: 10));
      expect(h.repo.saves, hasLength(1));
      expect(h.cubit.state, state);
    });

    test(
      'PRC-03: close during start prevents late emissions or ticker',
      () async {
        final response = Completer<Result<QuizSession>>();
        h.repo.onStart = (_) => response.future;
        final pending = h.cubit.start('topic');
        await h.cubit.close();
        response.complete(Success(h.repo.session));
        await pending;
        expect(h.cubit.state, const QuizLoading());
        expect(h.ticks.hasListener, isFalse);
      },
    );

    test(
      'PRC-03: close during save prevents retry and late emissions',
      () async {
        final response = Completer<Result<SaveOutcome>>();
        h.repo.onSave = (_) => response.future;
        await h.cubit.start('topic');
        h.cubit.select('A');
        final state = h.cubit.state;
        await h.cubit.close();
        response.complete(const Failure(_network));
        await _settle();
        await h.tick(const Duration(seconds: 10));
        expect(h.cubit.state, state);
        expect(h.repo.saves, hasLength(1));
      },
    );

    test(
      'PRC-03: close while submit awaits save prevents submit request',
      () async {
        final response = Completer<Result<SaveOutcome>>();
        h.repo.onSave = (_) => response.future;
        await h.cubit.start('topic');
        h.cubit.select('A');
        final pending = h.cubit.submit();
        await h.cubit.close();
        response.complete(const Success(SaveOutcome.saved));
        await pending;
        expect(h.repo.submitted, isEmpty);
      },
    );

    test('PRC-03: close during submit prevents late result emission', () async {
      final response = Completer<Result<QuizReport>>();
      h.repo.onSubmit = (_) => response.future;
      await h.cubit.start('topic');
      final pending = h.cubit.submit();
      await _settle();
      final state = h.cubit.state;
      await h.cubit.close();
      response.complete(const Success(_report));
      await pending;
      expect(h.cubit.state, state);
    });

    test(
      'PRC-03: older start response cannot replace the newest session',
      () async {
        final first = Completer<Result<QuizSession>>();
        h.repo.onStart = (topic) => topic == 'old'
            ? first.future
            : Future.value(Success(_session(attemptId: 'new')));
        final old = h.cubit.start('old');
        await h.cubit.start('new');
        first.complete(Success(h.repo.session));
        await old;
        expect(h.running.session.attemptId, 'new');
      },
    );

    test(
      'PRC-03: new start clears old pending saves and their results',
      () async {
        final save = Completer<Result<SaveOutcome>>();
        h.repo.onSave = (_) => save.future;
        await h.cubit.start('old');
        h.cubit.select('A');
        h.cubit.select('B');
        h.repo.session = _session(attemptId: 'new');
        await h.cubit.start('new');
        save.complete(const Failure(_network));
        await _settle();
        await h.tick(const Duration(seconds: 10));
        expect(h.running.session.attemptId, 'new');
        expect(h.running.answers, isEmpty);
        expect(h.running.saveError, isNull);
        expect(h.repo.saves, hasLength(1));
      },
    );

    test(
      'PRC-03: old submit response cannot overwrite a restarted quiz',
      () async {
        final report = Completer<Result<QuizReport>>();
        h.repo.onSubmit = (_) => report.future;
        await h.cubit.start('old');
        final pending = h.cubit.submit();
        await _settle();
        h.repo.session = _session(attemptId: 'new');
        await h.cubit.start('new');
        report.complete(const Success(_report));
        await pending;
        expect(h.running.session.attemptId, 'new');
      },
    );
  });
}
