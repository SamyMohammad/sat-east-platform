import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:sat_east_client/core/di/injection.dart';
import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/core/theme/app_theme.dart';
import 'package:sat_east_client/features/practice/domain/entities/practice.dart';
import 'package:sat_east_client/features/practice/presentation/cubit/practice_cubit.dart';
import 'package:sat_east_client/features/practice/presentation/cubit/practice_state.dart';
import 'package:sat_east_client/features/practice/presentation/screens/practice_screen.dart';
import 'package:sat_east_client/shared/widgets/booklet_skeleton.dart';
import 'package:sat_east_client/shared/widgets/question_view/practice_feedback.dart'
    as feedback;
import 'package:sat_east_client/shared/widgets/question_view/question_data.dart';
import 'package:sat_east_client/shared/widgets/question_view/question_view.dart';
import 'package:sat_east_client/shared/widgets/question_view/question_view_mode.dart';

class _MockCubit extends MockCubit<PracticeState> implements PracticeCubit {}

PracticeInProgress _progress({
  PracticeStep step = const Answering(),
  PracticeKind kind = PracticeKind.mcq,
  String difficulty = 'M',
  String? firstTry,
  AppError? error,
}) => PracticeInProgress(
  set: PracticeSet(
    attemptId: 'a1',
    repTarget: 3,
    questions: [
      PracticeQuestion(
        id: 'q1',
        kind: kind,
        difficulty: difficulty,
        stemMd: 'Solve this equation.',
        choices: kind == PracticeKind.mcq
            ? const [PracticeChoice('A', 'One'), PracticeChoice('B', 'Two')]
            : const [],
      ),
    ],
  ),
  index: 0,
  selected: kind == PracticeKind.mcq ? 'B' : null,
  sprText: kind == PracticeKind.spr ? '1/2' : '',
  feedback: step,
  firstTry: firstTry,
  checkError: error,
);

_MockCubit _cubit(PracticeState state) {
  final cubit = _MockCubit();
  whenListen(cubit, const Stream<PracticeState>.empty(), initialState: state);
  when(() => cubit.start(any())).thenAnswer((_) async {});
  when(cubit.check).thenAnswer((_) async {});
  when(cubit.practiceMore).thenAnswer((_) async {});
  when(cubit.close).thenAnswer((_) async {});
  return cubit;
}

Future<GoRouter> _pump(
  WidgetTester tester,
  _MockCubit cubit, {
  Size size = const Size(360, 800),
  String? title,
  bool screen = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: '/practice',
    routes: [
      GoRoute(
        path: '/courses',
        builder: (_, _) => const Scaffold(body: Text('Course map')),
      ),
      GoRoute(
        path: '/practice',
        builder: (_, _) => Scaffold(
          body: screen
              ? PracticeScreen(topicId: 'topic-1', title: title)
              : BlocProvider<PracticeCubit>.value(
                  value: cubit,
                  child: PracticeView(topicId: 'topic-1', title: title),
                ),
        ),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  return router;
}

QuestionView _question(WidgetTester tester) =>
    tester.widget<QuestionView>(find.byType(QuestionView));
feedback.PracticeFeedback _feedback(WidgetTester tester) =>
    (_question(tester).mode as PracticeMode).feedback;

void main() {
  testWidgets('PRC-01: loading shows a skeleton', (tester) async {
    await _pump(tester, _cubit(const PracticeLoading()));
    expect(find.byType(BookletSkeleton), findsOneWidget);
  });

  testWidgets('PRC-01: answering maps MCQ data, progress and answer', (
    tester,
  ) async {
    await _pump(tester, _cubit(_progress()), title: 'Systems');
    final view = _question(tester);
    expect(view.title, 'Systems');
    expect(view.question.id, 'q1');
    expect(view.question.label, 'Question 1');
    expect(view.question.stemMd, 'Solve this equation.');
    expect(view.question.difficulty, QuestionDifficulty.medium);
    final choices = (view.question.kind as McqKind).choices;
    expect(choices.map((c) => (c.label, c.md)), [('A', 'One'), ('B', 'Two')]);
    expect(view.answer.selected, 'B');
    expect(_feedback(tester), isA<feedback.Idle>());
    expect((view.mode as PracticeMode).rep, 1);
    expect((view.mode as PracticeMode).repTarget, 3);
    expect(find.text('Solve this equation.'), findsOneWidget);
    expect(view.onPrev, isNull);
    expect(find.text('Back'), findsNothing);
  });

  for (final (code, expected) in [
    ('E', QuestionDifficulty.easy),
    ('H', QuestionDifficulty.hard),
  ]) {
    testWidgets('PRC-01: $code difficulty maps to $expected', (tester) async {
      await _pump(tester, _cubit(_progress(difficulty: code)));
      expect(_question(tester).question.difficulty, expected);
    });
  }

  testWidgets('PRC-01: SPR answer and callbacks are forwarded', (tester) async {
    final cubit = _cubit(_progress(kind: PracticeKind.spr));
    await _pump(tester, cubit);
    final view = _question(tester);
    expect(view.title, 'Practice');
    expect(view.question.kind, isA<SprKind>());
    expect(view.answer.sprText, '1/2');
    view.onSprChanged!('.5');
    view.onCheck!();
    verify(() => cubit.sprChanged('.5')).called(1);
    verify(cubit.check).called(1);
  });

  testWidgets('PRC-01: MCQ selection and next callbacks reach cubit', (
    tester,
  ) async {
    final cubit = _cubit(_progress());
    await _pump(tester, cubit);
    _question(tester).onSelect!('A');
    _question(tester).onNext!();
    verify(() => cubit.select('A')).called(1);
    verify(cubit.next).called(1);
  });

  testWidgets('PRC-01: checking maps to Checking feedback', (tester) async {
    await _pump(tester, _cubit(_progress(step: const Checking())));
    expect(_feedback(tester), isA<feedback.Checking>());
  });

  testWidgets('PRC-01: first miss preserves answer, hint and misconception', (
    tester,
  ) async {
    await _pump(
      tester,
      _cubit(
        _progress(
          step: const MissedOnce(
            missed: 'A',
            hintMd: 'Try isolating x.',
            misconceptionMd: 'Remember the sign.',
          ),
        ),
      ),
    );
    final value = _feedback(tester) as feedback.FirstMiss;
    expect(value.missed, 'A');
    expect(value.hintMd, 'Try isolating x.');
    expect(value.noteMd, 'Remember the sign.');
    expect(find.text('Try isolating x.'), findsOneWidget);
    expect(find.text('Remember the sign.'), findsOneWidget);
  });

  for (final firstTry in <String?>[null, 'A']) {
    testWidgets(
      'PRC-01: correct renders explanation with first try $firstTry',
      (tester) async {
        await _pump(
          tester,
          _cubit(
            _progress(
              firstTry: firstTry,
              step: Done(
                CheckCorrect(
                  tryNo: firstTry == null ? 1 : 2,
                  key: const ChoiceReveal('B'),
                  explanationMd: 'The solution is two.',
                ),
              ),
            ),
          ),
        );
        final value = _feedback(tester) as feedback.Correct;
        expect(value.firstTry, firstTry);
        expect(value.explanationMd, 'The solution is two.');
        expect(find.text('The solution is two.'), findsOneWidget);
        expect(find.text('Next'), findsOneWidget);
      },
    );
  }

  for (final kind in PracticeKind.values) {
    testWidgets('PRC-01: revealed $kind maps server key and first try', (
      tester,
    ) async {
      await _pump(
        tester,
        _cubit(
          _progress(
            kind: kind,
            firstTry: 'A',
            step: Done(
              CheckRevealed(
                key: kind == PracticeKind.mcq
                    ? const ChoiceReveal('B')
                    : const TextReveal('1/2'),
                explanationMd: 'Use the inverse operation.',
              ),
            ),
          ),
        ),
      );
      final value = _feedback(tester) as feedback.Revealed;
      expect(value.firstTry, 'A');
      if (kind == PracticeKind.mcq) {
        expect((value.key as feedback.McqAnswerKey).label, 'B');
      } else {
        expect((value.key as feedback.SprAnswerKey).text, '1/2');
      }
      expect(value.explanationMd, 'Use the inverse operation.');
      expect(find.text('Use the inverse operation.'), findsOneWidget);
    });
  }

  for (final (code, body) in [
    (
      ErrorCodes.topicLocked,
      'This topic is locked. Pass the previous quiz first.',
    ),
    (ErrorCodes.poolExhausted, 'No practice questions yet.'),
    (ErrorCodes.notEnrolled, "You're not enrolled in a course yet."),
    (ErrorCodes.accessExpired, 'Your access has ended. Contact your teacher.'),
    (ErrorCodes.network, 'Check your connection and try again.'),
    (ErrorCodes.internal, 'Something went wrong. Try again.'),
  ]) {
    testWidgets('PRC-01: $code renders safe error copy', (tester) async {
      await _pump(
        tester,
        _cubit(PracticeFailed(AppError(code, 'secret database details'))),
      );
      expect(find.text(body), findsOneWidget);
      expect(find.textContaining('secret database details'), findsNothing);
      if (code == ErrorCodes.network || code == ErrorCodes.internal) {
        expect(find.text("Couldn't load practice"), findsOneWidget);
        expect(find.text('Retry'), findsOneWidget);
      }
    });
  }

  testWidgets('PRC-01: retry starts the current topic', (tester) async {
    final cubit = _cubit(const PracticeFailed(AppError(ErrorCodes.network)));
    await _pump(tester, cubit);
    await tester.tap(find.text('Retry'));
    verify(() => cubit.start('topic-1')).called(1);
  });

  testWidgets('PRC-01: failed check keeps answer and enables retry', (
    tester,
  ) async {
    final cubit = _cubit(_progress(error: const AppError(ErrorCodes.network)));
    await _pump(tester, cubit);
    expect(find.text("Couldn't check your answer. Try again."), findsOneWidget);
    expect(_question(tester).answer.selected, 'B');
    expect(_feedback(tester), isA<feedback.Idle>());
    await tester.tap(find.text('Check'));
    verify(cubit.check).called(1);
  });

  testWidgets('PRC-01: app bar back returns to courses', (tester) async {
    final router = await _pump(tester, _cubit(_progress()));
    _question(tester).onBack!();
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/courses');
    expect(find.text('Course map'), findsOneWidget);
  });

  testWidgets('PRC-01: failed second check keeps hint and revised answer', (
    tester,
  ) async {
    final cubit = _cubit(
      _progress(
        step: const MissedOnce(missed: 'A', hintMd: 'Try isolating x.'),
        firstTry: 'A',
        error: const AppError(ErrorCodes.network),
      ),
    );
    await _pump(tester, cubit);
    final value = _feedback(tester) as feedback.FirstMiss;
    expect(value.missed, 'A');
    expect(value.hintMd, 'Try isolating x.');
    expect(_question(tester).answer.selected, 'B');
    expect(
      find.text("Couldn't check your answer. Try again."),
      findsOneWidget,
    );
    await tester.tap(find.text('Check'));
    verify(cubit.check).called(1);
  });

  testWidgets('PRC-01: summary renders counts and starts practice more', (
    tester,
  ) async {
    final cubit = _cubit(const PracticeSummary(correctFirstTry: 2, total: 3));
    await _pump(tester, cubit);
    expect(find.text('Practice complete'), findsOneWidget);
    expect(find.text('You got 2 of 3 right on the first try.'), findsOneWidget);
    await tester.tap(find.text('Practice more'));
    verify(cubit.practiceMore).called(1);
  });

  testWidgets('PRC-01: summary back returns to courses', (tester) async {
    final router = await _pump(
      tester,
      _cubit(const PracticeSummary(correctFirstTry: 2, total: 3)),
    );
    await tester.tap(find.text('Back to course'));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/courses');
  });

  for (final width in [360.0, 1280.0]) {
    for (final (name, state) in <(String, PracticeState)>[
      (
        'feedback',
        _progress(
          step: const MissedOnce(
            missed: 'A',
            hintMd: 'Try isolating x.',
            misconceptionMd: 'Remember the sign.',
          ),
        ),
      ),
      ('check error', _progress(error: const AppError(ErrorCodes.network))),
      ('error', const PracticeFailed(AppError(ErrorCodes.topicLocked))),
      ('summary', const PracticeSummary(correctFirstTry: 2, total: 3)),
    ]) {
      testWidgets('PRC-01: $name fits ${width}x800', (tester) async {
        await _pump(tester, _cubit(state), size: Size(width, 800));
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('PRC-01: screen resolves one cubit, starts topic and closes it', (
    tester,
  ) async {
    final cubit = _cubit(_progress());
    var created = 0;
    getIt.registerFactory<PracticeCubit>(() {
      created++;
      return cubit;
    });
    addTearDown(() => getIt.unregister<PracticeCubit>());
    await _pump(tester, cubit, screen: true);
    expect(created, 1);
    verify(() => cubit.start('topic-1')).called(1);
    await tester.pump();
    verifyNever(() => cubit.start('topic-1'));
    await tester.pumpWidget(const SizedBox.shrink());
    verify(cubit.close).called(1);
  });

  testWidgets('PRC-01: changing topic creates a fresh practice session', (
    tester,
  ) async {
    final first = _cubit(_progress());
    final second = _cubit(_progress());
    var created = 0;
    getIt.registerFactory<PracticeCubit>(
      () => created++ == 0 ? first : second,
    );
    addTearDown(() => getIt.unregister<PracticeCubit>());
    Widget screen(String topicId) => MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: PracticeScreen(topicId: topicId)),
    );
    await tester.pumpWidget(screen('first-topic'));
    verify(() => first.start('first-topic')).called(1);
    await tester.pumpWidget(screen('first-topic'));
    expect(created, 1);
    verifyNever(() => first.start(any()));
    await tester.pumpWidget(screen('second-topic'));
    await tester.pump();
    expect(created, 2);
    verify(() => second.start('second-topic')).called(1);
    verify(first.close).called(1);
    await tester.pumpWidget(const SizedBox.shrink());
    verify(second.close).called(1);
  });
}
