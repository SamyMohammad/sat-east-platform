import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/practice/domain/entities/practice.dart';
import 'package:sat_east_client/features/practice/domain/repositories/practice_repository.dart';
import 'package:sat_east_client/features/practice/presentation/cubit/practice_cubit.dart';
import 'package:sat_east_client/features/practice/presentation/cubit/practice_state.dart';

class _MockRepo extends Mock implements PracticeRepository {}

const _mcq = PracticeQuestion(
  id: 'q1',
  kind: PracticeKind.mcq,
  difficulty: 'E',
  stemMd: 'Solve.',
  choices: [PracticeChoice('A', 'One'), PracticeChoice('B', 'Two')],
);
const _spr = PracticeQuestion(
  id: 'q2',
  kind: PracticeKind.spr,
  difficulty: 'M',
  stemMd: 'Solve.',
  choices: [],
);
const _set = PracticeSet(
  attemptId: 'a1',
  repTarget: 2,
  questions: [_mcq, _spr],
);
const _correct = CheckCorrect(
  tryNo: 1,
  key: ChoiceReveal('B'),
  explanationMd: 'Explanation',
);
const _correctSecond = CheckCorrect(
  tryNo: 2,
  key: ChoiceReveal('B'),
  explanationMd: 'Explanation',
);
const _miss = CheckMiss(hintMd: 'Hint', misconceptionMd: 'Note');
const _missed = MissedOnce(
  missed: 'A',
  hintMd: 'Hint',
  misconceptionMd: 'Note',
);
const _revealed = CheckRevealed(
  key: ChoiceReveal('B'),
  explanationMd: 'Explanation',
);
const _network = AppError(ErrorCodes.network);

PracticeInProgress _progress({
  int index = 0,
  String? selected,
  String sprText = '',
  PracticeStep feedback = const Answering(),
  String? firstTry,
  AppError? checkError,
}) => PracticeInProgress(
  set: _set,
  index: index,
  selected: selected,
  sprText: sprText,
  feedback: feedback,
  firstTry: firstTry,
  checkError: checkError,
);

void main() {
  late _MockRepo repo;
  late DateTime clock;

  PracticeCubit build() => PracticeCubit(repo, () => clock);

  void checks(List<Result<CheckResult>> results) {
    var call = 0;
    when(
      () => repo.check(
        attemptId: any(named: 'attemptId'),
        questionId: any(named: 'questionId'),
        answer: any(named: 'answer'),
        timeMs: any(named: 'timeMs'),
      ),
    ).thenAnswer((_) async => results[call++]);
  }

  VerificationResult checked(String answer, {String questionId = 'q1'}) =>
      verify(
        () => repo.check(
          attemptId: 'a1',
          questionId: questionId,
          answer: answer,
          timeMs: any(named: 'timeMs'),
        ),
      );

  setUp(() {
    repo = _MockRepo();
    clock = DateTime.utc(2026, 10, 17, 12);
    when(() => repo.start(any())).thenAnswer((_) async => const Success(_set));
  });

  blocTest<PracticeCubit, PracticeState>(
    'PRC-01: start emits Loading then the first unanswered question',
    build: build,
    act: (c) => c.start('topic'),
    expect: () => [const PracticeLoading(), _progress()],
    verify: (_) => verify(() => repo.start('topic')).called(1),
  );

  for (final code in [
    ErrorCodes.topicLocked,
    ErrorCodes.accessExpired,
    ErrorCodes.notEnrolled,
    ErrorCodes.poolExhausted,
    ErrorCodes.network,
  ]) {
    blocTest<PracticeCubit, PracticeState>(
      'PRC-01: start propagates $code',
      build: () {
        when(() => repo.start(any())).thenAnswer(
          (_) async => Failure(AppError(code)),
        );
        return build();
      },
      act: (c) => c.start('topic'),
      expect: () => [const PracticeLoading(), PracticeFailed(AppError(code))],
    );
  }

  blocTest<PracticeCubit, PracticeState>(
    'PRC-01: an empty set becomes pool_exhausted',
    build: () {
      when(() => repo.start(any())).thenAnswer(
        (_) async => const Success(
          PracticeSet(attemptId: 'empty', repTarget: 0, questions: []),
        ),
      );
      return build();
    },
    act: (c) => c.start('topic'),
    expect: () => [
      const PracticeLoading(),
      const PracticeFailed(AppError(ErrorCodes.poolExhausted)),
    ],
  );

  blocTest<PracticeCubit, PracticeState>(
    'PRC-01: MCQ check sends the selected label and uses server correctness',
    build: () {
      checks([const Success(_correct)]);
      return build();
    },
    act: (c) async {
      await c.start('topic');
      c.select('A');
      await c.check();
    },
    skip: 3,
    expect: () => [
      _progress(selected: 'A', feedback: const Checking()),
      _progress(selected: 'A', feedback: const Done(_correct)),
    ],
    verify: (_) => checked('A').called(1),
  );

  for (final result in <CheckResult>[_correctSecond, _revealed]) {
    blocTest<PracticeCubit, PracticeState>(
      'PRC-01: miss then ${result.runtimeType} keeps the first missed answer',
      build: () {
        checks([const Success(_miss), Success(result)]);
        return build();
      },
      act: (c) async {
        await c.start('topic');
        c.select('A');
        await c.check();
        c.select('B');
        await c.check();
      },
      skip: 3,
      expect: () => [
        _progress(selected: 'A', feedback: const Checking()),
        _progress(selected: 'A', feedback: _missed, firstTry: 'A'),
        _progress(selected: 'B', feedback: _missed, firstTry: 'A'),
        _progress(selected: 'B', feedback: const Checking(), firstTry: 'A'),
        _progress(selected: 'B', feedback: Done(result), firstTry: 'A'),
      ],
    );
  }

  for (final step in <PracticeStep>[const Answering(), _missed]) {
    for (final code in [ErrorCodes.network, ErrorCodes.internal]) {
      final firstTry = step is MissedOnce ? 'A' : null;
      blocTest<PracticeCubit, PracticeState>(
        'PRC-01: $code restores ${step.runtimeType} '
        'and retries the same answer',
        build: () {
          checks([
            if (step is MissedOnce) const Success(_miss),
            Failure(AppError(code)),
            const Success(_correctSecond),
          ]);
          return build();
        },
        act: (c) async {
          await c.start('topic');
          if (step is MissedOnce) {
            c.select('A');
            await c.check();
          }
          c.select('B');
          await c.check();
          await c.check();
        },
        skip: step is MissedOnce ? 6 : 3,
        expect: () => [
          _progress(
            selected: 'B',
            feedback: const Checking(),
            firstTry: firstTry,
          ),
          _progress(
            selected: 'B',
            feedback: step,
            firstTry: firstTry,
            checkError: AppError(code),
          ),
          _progress(
            selected: 'B',
            feedback: const Checking(),
            firstTry: firstTry,
            checkError: AppError(code),
          ),
          _progress(
            selected: 'B',
            feedback: const Done(_correctSecond),
            firstTry: firstTry,
          ),
        ],
        verify: (_) => checked('B').called(2),
      );
    }
  }

  for (final afterMiss in [false, true]) {
    for (final isSpr in [false, true]) {
      test(
        'PRC-01: failed ${isSpr ? 'SPR' : 'MCQ'} check locks the answer '
        'and retries it after ${afterMiss ? 'MissedOnce' : 'Answering'}',
        () async {
          checks([
            if (isSpr) const Success(_correct),
            if (afterMiss) const Success(_miss),
            const Failure(_network),
            const Success(_correctSecond),
          ]);
          final c = build();
          addTearDown(c.close);
          await c.start('topic');
          if (isSpr) {
            c.select('A');
            await c.check();
            c.next();
          }
          void answer(String value) {
            if (isSpr) {
              c.sprChanged(value);
            } else {
              c.select(value);
            }
          }

          if (afterMiss) {
            answer(isSpr ? '1' : 'B');
            await c.check();
          }
          answer(isSpr ? '5' : 'A');
          await c.check();
          final failed = c.state as PracticeInProgress;
          expect(failed.checkError, _network);
          expect(
            failed.feedback,
            afterMiss ? isA<MissedOnce>() : isA<Answering>(),
          );
          answer(isSpr ? '6' : 'B');
          expect(c.state, failed);
          await c.check();
          checked(isSpr ? '5' : 'A', questionId: isSpr ? 'q2' : 'q1').called(2);
          expect((c.state as PracticeInProgress).checkError, isNull);
        },
      );
    }
  }

  for (final afterMiss in [false, true]) {
    for (final code in [
      ErrorCodes.topicLocked,
      ErrorCodes.accessExpired,
      ErrorCodes.notEnrolled,
    ]) {
      blocTest<PracticeCubit, PracticeState>(
        'PRC-01: check $code ends practice after '
        '${afterMiss ? 'MissedOnce' : 'Answering'}',
        build: () {
          checks([
            if (afterMiss) const Success(_miss),
            Failure(AppError(code)),
          ]);
          return build();
        },
        act: (c) async {
          await c.start('topic');
          c.select('A');
          if (afterMiss) {
            await c.check();
            c.select('B');
          }
          await c.check();
        },
        skip: afterMiss ? 7 : 4,
        expect: () => [PracticeFailed(AppError(code))],
      );
    }
  }

  test('PRC-01: SPR checks and missed answers use trimmed text', () async {
    checks([
      const Success(_correct),
      const Success(_miss),
      const Success(_miss),
    ]);
    final c = build();
    addTearDown(c.close);
    await c.start('topic');
    c.select('A');
    await c.check();
    c
      ..next()
      ..sprChanged(' 5 ');
    await c.check();
    var current = c.state as PracticeInProgress;
    expect(current.firstTry, '5');
    expect((current.feedback as MissedOnce).missed, '5');
    c.sprChanged('5 ');
    await c.check();
    current = c.state as PracticeInProgress;
    expect(current.firstTry, '5');
    expect((current.feedback as MissedOnce).missed, '5');
    checked('5', questionId: 'q2').called(2);
  });

  blocTest<PracticeCubit, PracticeState>(
    'PRC-01: next advances and clears answers, feedback and firstTry',
    build: () {
      checks([const Success(_miss), const Success(_correctSecond)]);
      return build();
    },
    act: (c) async {
      await c.start('topic');
      c.select('A');
      await c.check();
      c.select('B');
      await c.check();
      c.next();
    },
    skip: 8,
    expect: () => [_progress(index: 1)],
  );

  test('PRC-01: summary counts only server correct try 1', () async {
    checks([const Success(_correct), const Success(_correctSecond)]);
    final c = build();
    addTearDown(c.close);
    await c.start('topic');
    c.select('A');
    await c.check();
    c
      ..next()
      ..sprChanged('server decides');
    await c.check();
    c.next();
    expect(c.state, const PracticeSummary(correctFirstTry: 1, total: 2));
  });

  test(
    'PRC-01: practiceMore starts the same topic and resets the count',
    () async {
      checks([
        const Success(_correct),
        const Success(_correct),
        const Success(_revealed),
        const Success(_revealed),
      ]);
      final c = build();
      addTearDown(c.close);
      await c.start('topic');
      for (var round = 0; round < 2; round++) {
        c.select('A');
        await c.check();
        c
          ..next()
          ..sprChanged('x');
        await c.check();
        c.next();
        expect(
          c.state,
          PracticeSummary(correctFirstTry: round == 0 ? 2 : 0, total: 2),
        );
        if (round == 0) {
          await c.practiceMore();
          expect(c.state, _progress());
        }
      }
      verify(() => repo.start('topic')).called(2);
    },
  );

  test(
    'PRC-01: elapsed time uses question shown and previous check times',
    () async {
      checks([const Success(_miss), const Success(_correctSecond)]);
      final c = build();
      addTearDown(c.close);
      await c.start('topic');
      c.select('A');
      clock = clock.add(const Duration(milliseconds: 4200));
      await c.check();
      c.select('B');
      clock = clock.add(const Duration(milliseconds: 1700));
      await c.check();
      verify(
        () => repo.check(
          attemptId: 'a1',
          questionId: 'q1',
          answer: 'A',
          timeMs: 4200,
        ),
      ).called(1);
      verify(
        () => repo.check(
          attemptId: 'a1',
          questionId: 'q1',
          answer: 'B',
          timeMs: 1700,
        ),
      ).called(1);
    },
  );

  test(
    'PRC-01: a failed check keeps the elapsed-time anchor for retry',
    () async {
      checks([const Failure(_network), const Success(_correct)]);
      final c = build();
      addTearDown(c.close);
      await c.start('topic');
      c.select('A');
      clock = clock.add(const Duration(milliseconds: 4200));
      await c.check();
      clock = clock.add(const Duration(milliseconds: 1800));
      await c.check();
      final times = verify(
        () => repo.check(
          attemptId: 'a1',
          questionId: 'q1',
          answer: 'A',
          timeMs: captureAny(named: 'timeMs'),
        ),
      ).captured;
      expect(times, [4200, 6000]);
    },
  );

  test(
    'PRC-01: next starts timing from when the next question is shown',
    () async {
      checks([const Success(_correct), const Success(_revealed)]);
      final c = build();
      addTearDown(c.close);
      await c.start('topic');
      c.select('A');
      clock = clock.add(const Duration(seconds: 4));
      await c.check();
      clock = clock.add(const Duration(seconds: 10));
      c
        ..next()
        ..sprChanged('answer');
      clock = clock.add(const Duration(milliseconds: 4200));
      await c.check();
      verify(
        () => repo.check(
          attemptId: 'a1',
          questionId: 'q2',
          answer: 'answer',
          timeMs: 4200,
        ),
      ).called(1);
    },
  );

  for (final index in [0, 1]) {
    blocTest<PracticeCubit, PracticeState>(
      'PRC-01: cannot check an empty ${index == 0 ? 'MCQ' : 'SPR'} answer',
      build: () {
        when(() => repo.start(any())).thenAnswer(
          (_) async => Success(
            PracticeSet(
              attemptId: 'a1',
              repTarget: 1,
              questions: [if (index == 0) _mcq else _spr],
            ),
          ),
        );
        return build();
      },
      act: (c) async {
        await c.start('topic');
        await c.check();
      },
      skip: 2,
      expect: () => <PracticeState>[],
      verify: (_) => verifyNever(
        () => repo.check(
          attemptId: any(named: 'attemptId'),
          questionId: any(named: 'questionId'),
          answer: any(named: 'answer'),
          timeMs: any(named: 'timeMs'),
        ),
      ),
    );
  }

  for (final step in <PracticeStep>[const Answering(), _missed]) {
    blocTest<PracticeCubit, PracticeState>(
      'PRC-01: next is ignored during ${step.runtimeType}',
      build: () {
        checks([const Success(_miss)]);
        return build();
      },
      act: (c) async {
        await c.start('topic');
        if (step is MissedOnce) {
          c.select('A');
          await c.check();
        }
        c.next();
      },
      skip: step is MissedOnce ? 5 : 2,
      expect: () => <PracticeState>[],
    );
  }

  for (final pending in [true, false]) {
    test(
      'PRC-01: edits and repeated check are ignored '
      'while ${pending ? 'Checking' : 'Done'}',
      () async {
        final reply = Completer<Result<CheckResult>>();
        when(
          () => repo.check(
            attemptId: any(named: 'attemptId'),
            questionId: any(named: 'questionId'),
            answer: any(named: 'answer'),
            timeMs: any(named: 'timeMs'),
          ),
        ).thenAnswer((_) => reply.future);
        final c = build();
        addTearDown(c.close);
        await c.start('topic');
        c.select('A');
        final checking = c.check();
        if (!pending) {
          reply.complete(const Success(_correct));
          await checking;
        }
        final before = c.state;
        c
          ..select('B')
          ..sprChanged('changed');
        await c.check();
        expect(c.state, before);
        if (pending) c.next();
        expect(c.state, before);
        if (pending) {
          reply.complete(const Success(_correct));
          await checking;
        }
        verify(
          () => repo.check(
            attemptId: any(named: 'attemptId'),
            questionId: any(named: 'questionId'),
            answer: any(named: 'answer'),
            timeMs: any(named: 'timeMs'),
          ),
        ).called(1);
      },
    );
  }

  test('PRC-01: closing during start ignores its late response', () async {
    final reply = Completer<Result<PracticeSet>>();
    when(() => repo.start(any())).thenAnswer((_) => reply.future);
    final c = build();
    final pending = c.start('topic');
    await c.close();
    reply.complete(const Success(_set));
    await pending;
    expect(c.state, const PracticeLoading());
  });

  test('PRC-01: closing during check ignores its late response', () async {
    final reply = Completer<Result<CheckResult>>();
    when(
      () => repo.check(
        attemptId: any(named: 'attemptId'),
        questionId: any(named: 'questionId'),
        answer: any(named: 'answer'),
        timeMs: any(named: 'timeMs'),
      ),
    ).thenAnswer((_) => reply.future);
    final c = build();
    await c.start('topic');
    c.select('A');
    final pending = c.check();
    await c.close();
    reply.complete(const Success(_correct));
    await pending;
    expect((c.state as PracticeInProgress).feedback, const Checking());
  });

  test('PRC-01: a stale start cannot replace a newer topic', () async {
    final reply = Completer<Result<PracticeSet>>();
    when(() => repo.start('old')).thenAnswer((_) => reply.future);
    final c = build();
    addTearDown(c.close);
    final pending = c.start('old');
    await c.start('new');
    reply.complete(const Failure(AppError(ErrorCodes.topicLocked)));
    await pending;
    expect(c.state, _progress());
  });

  test('PRC-01: a check from an old set cannot replace a new set', () async {
    final reply = Completer<Result<CheckResult>>();
    when(
      () => repo.check(
        attemptId: any(named: 'attemptId'),
        questionId: any(named: 'questionId'),
        answer: any(named: 'answer'),
        timeMs: any(named: 'timeMs'),
      ),
    ).thenAnswer((_) => reply.future);
    final c = build();
    addTearDown(c.close);
    await c.start('old');
    c.select('A');
    final pending = c.check();
    await c.start('new');
    reply.complete(const Success(_correct));
    await pending;
    expect(c.state, _progress());
  });
}
