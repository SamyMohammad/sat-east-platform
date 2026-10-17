part of 'quiz_cubit_test.dart';

void _autosaveCases() {
  group('QuizCubit', () {
    late _Harness h;
    setUp(() => h = _Harness());
    tearDown(() => h.close());

    test(
      'PRC-03: selecting an answer saves the exact attempt and sequence',
      () async {
        await h.cubit.start('topic');
        await h.tick(const Duration(milliseconds: 1500));
        h.cubit.select('B');
        await _settle();
        final saved = h.repo.saves.single;
        expect(h.running.answers, {'mcq': 'B'});
        expect(saved.attemptId, 'attempt');
        expect(saved.questionId, 'mcq');
        expect(saved.answer, 'B');
        expect(saved.marked, isFalse);
        expect(saved.timeMs, 1500);
        expect(saved.clientSeq, 1);
        expect(saved.eliminated, isEmpty);
      },
    );

    test(
      'PRC-03: in-flight edits coalesce to the latest answer and mark',
      () async {
        final first = Completer<Result<SaveOutcome>>();
        h.repo.onSave = (_) => h.repo.saves.length == 1
            ? first.future
            : Future.value(const Success(SaveOutcome.saved));
        await h.cubit.start('topic');
        h.cubit.select('A');
        h.cubit.select('B');
        h.cubit.select('A');
        h.cubit.toggleMark();
        await _settle();
        expect(h.repo.saves, hasLength(1));
        expect(h.repo.saves.first.answer, 'A');
        expect(h.repo.saves.first.marked, isFalse);
        first.complete(const Success(SaveOutcome.saved));
        await _settle();
        expect(h.repo.saves, hasLength(2));
        expect(h.repo.saves.last.answer, 'A');
        expect(h.repo.saves.last.marked, isTrue);
        expect(h.repo.saves.map((s) => s.clientSeq), [1, 2]);
      },
    );

    test('PRC-03: pending edits remain separate for each question', () async {
      final first = Completer<Result<SaveOutcome>>();
      h.repo.onSave = (_) => h.repo.saves.length == 1
          ? first.future
          : Future.value(const Success(SaveOutcome.saved));
      await h.cubit.start('topic');
      h.cubit.select('A');
      h.cubit.select('B');
      h.cubit.next();
      h.cubit.sprChanged('1/2');
      h.cubit.sprChanged(' 0.5 ');
      first.complete(const Success(SaveOutcome.saved));
      await _settle();
      expect(h.repo.saves, hasLength(3));
      expect(h.repo.saves.map((s) => s.clientSeq), [1, 2, 3]);
      final latest = {for (final s in h.repo.saves) s.questionId: s.answer};
      expect(latest, {'mcq': 'B', 'spr': ' 0.5 '});
    });

    test(
      'PRC-03: marking unanswered questions saves null and toggles back',
      () async {
        await h.cubit.start('topic');
        h.cubit.toggleMark();
        await _settle();
        expect(h.running.marked, {'mcq'});
        expect(h.repo.saves.single.answer, isNull);
        expect(h.repo.saves.single.marked, isTrue);
        h.cubit.toggleMark();
        await _settle();
        expect(h.running.marked, isEmpty);
        expect(h.repo.saves.last.marked, isFalse);
      },
    );

    test(
      'PRC-03: duplicate or invalid choices and wrong input kinds do not save',
      () async {
        await h.cubit.start('topic');
        h.cubit.select('Z');
        h.cubit.sprChanged('123');
        expect(h.repo.saves, isEmpty);
        h.cubit.select('A');
        await _settle();
        h.cubit.select('A');
        expect(h.repo.saves, hasLength(1));
        h.cubit.next();
        h.cubit.select('B');
        h.cubit.sprChanged('1/2');
        await _settle();
        h.cubit.sprChanged('1/2');
        expect(h.repo.saves, hasLength(2));
        expect(h.running.answers['spr'], '1/2');
      },
    );

    test(
      'PRC-03: SPR text including empty clearing is saved verbatim',
      () async {
        await h.cubit.start('topic');
        h.cubit.next();
        h.cubit.sprChanged(' 1/2 ');
        await _settle();
        h.cubit.sprChanged('');
        await _settle();
        expect(h.repo.saves.map((s) => s.answer), [' 1/2 ', '']);
      },
    );

    test(
      'PRC-03: question time accumulates across visits '
      'without navigation saves',
      () async {
        await h.cubit.start('topic');
        await h.tick(const Duration(seconds: 3));
        h.cubit.next();
        await h.tick(const Duration(seconds: 7));
        h.cubit.prev();
        await h.tick(const Duration(seconds: 2));
        expect(h.repo.saves, isEmpty);
        h.cubit.select('A');
        await _settle();
        expect(h.repo.saves.single.timeMs, 5000);
        h.cubit.next();
        await h.tick(const Duration(seconds: 1));
        h.cubit.sprChanged('2');
        await _settle();
        expect(h.repo.saves.last.timeMs, 8000);
      },
    );

    test('PRC-03: stale save acknowledgement is successful', () async {
      h.repo.onSave = (_) async => const Success(SaveOutcome.stale);
      await h.cubit.start('topic');
      h.cubit.select('A');
      await _settle();
      expect(h.running.saveError, isNull);
      await h.tick(const Duration(seconds: 20));
      expect(h.repo.saves, hasLength(1));
    });

    test('PRC-03: queued save includes elapsed time up to dispatch', () async {
      final first = Completer<Result<SaveOutcome>>();
      h.repo.onSave = (_) => h.repo.saves.length == 1
          ? first.future
          : Future.value(const Success(SaveOutcome.saved));
      await h.cubit.start('topic');
      h.cubit.select('A');
      await h.tick(const Duration(seconds: 3));
      h.cubit.select('B');
      await h.tick(const Duration(seconds: 5));
      first.complete(const Success(SaveOutcome.saved));
      await _settle();
      expect(h.repo.saves.first.timeMs, 0);
      expect(h.repo.saves.last.timeMs, 8000);
    });

    test('PRC-03: answer changes preserve prior state snapshots', () async {
      await h.cubit.start('topic');
      final initial = h.running;
      h.cubit.select('A');
      final answered = h.running;
      h.cubit.toggleMark();
      expect(initial.answers, isEmpty);
      expect(initial.marked, isEmpty);
      expect(answered.answers, {'mcq': 'A'});
      expect(answered.marked, isEmpty);
      expect(h.running.marked, {'mcq'});
    });

    test('PRC-03: failed save retries at 2 then 5 then 10 seconds', () async {
      h.repo.onSave = (_) async => const Failure(_network);
      await h.cubit.start('topic');
      h.cubit.select('A');
      await _settle();
      expect(h.running.saveError, _network);
      for (final seconds in [2, 5, 10, 10]) {
        final before = h.repo.saves.length;
        await h.tick(Duration(seconds: seconds - 1));
        expect(h.repo.saves, hasLength(before));
        await h.tick(const Duration(seconds: 1));
        expect(h.repo.saves, hasLength(before + 1));
      }
      expect(h.repo.saves.map((s) => s.clientSeq), [1, 2, 3, 4, 5]);
      h.repo.onSave = (_) async => const Success(SaveOutcome.saved);
      await h.tick(const Duration(seconds: 10));
      expect(h.running.saveError, isNull);
      await h.tick(const Duration(seconds: 10));
      expect(h.repo.saves, hasLength(6));
    });

    test(
      'PRC-03: retry sends the latest edits made during the failed save',
      () async {
        final first = Completer<Result<SaveOutcome>>();
        h.repo.onSave = (_) => h.repo.saves.length == 1
            ? first.future
            : Future.value(const Success(SaveOutcome.saved));
        await h.cubit.start('topic');
        h.cubit.select('A');
        h.cubit.select('B');
        h.cubit.toggleMark();
        first.complete(const Failure(_network));
        await _settle();
        await h.tick(const Duration(seconds: 2));
        expect(h.repo.saves.last.answer, 'B');
        expect(h.repo.saves.last.marked, isTrue);
        expect(h.repo.saves.last.clientSeq, 2);
        expect(h.running.saveError, isNull);
      },
    );
  });
}
