import 'dart:async';

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
import 'package:sat_east_client/features/quiz/domain/entities/quiz.dart';
import 'package:sat_east_client/features/quiz/presentation/cubit/quiz_cubit.dart';
import 'package:sat_east_client/features/quiz/presentation/cubit/quiz_state.dart';
import 'package:sat_east_client/features/quiz/presentation/screens/quiz_result_screen.dart';
import 'package:sat_east_client/features/quiz/presentation/screens/quiz_screen.dart';
import 'package:sat_east_client/shared/widgets/app_skeleton.dart';
import 'package:sat_east_client/shared/widgets/question_view/parts/exam_bar.dart';
import 'package:sat_east_client/shared/widgets/question_view/parts/question_navigator.dart';
import 'package:sat_east_client/shared/widgets/question_view/question_data.dart';
import 'package:sat_east_client/shared/widgets/question_view/question_view.dart';
import 'package:sat_east_client/shared/widgets/question_view/question_view_mode.dart';

part 'quiz_widget_fixture.dart';
part 'quiz_result_cases.dart';

void main() {
  testWidgets('PRC-03: loading shows the shared skeleton', (tester) async {
    await _pump(tester, _cubit(const QuizLoading()));
    expect(find.byType(AppSkeleton), findsOneWidget);
  });

  testWidgets('PRC-03: screen creates, starts and closes one cubit', (
    tester,
  ) async {
    final cubit = _cubit(_running());
    var created = 0;
    getIt.registerFactory<QuizCubit>(() {
      created++;
      return cubit;
    });
    addTearDown(() => getIt.unregister<QuizCubit>());
    await _pump(tester, cubit, screen: true);
    expect(created, 1);
    verify(() => cubit.start('t1')).called(1);
    await tester.pumpWidget(const SizedBox.shrink());
    verify(cubit.close).called(1);
  });

  testWidgets('PRC-03: running maps question, answers, marks and timer', (
    tester,
  ) async {
    final state = _running();
    final cubit = _cubit(state);
    await _pump(tester, cubit);
    final view = _question(tester);
    final mode = view.mode as QuizMode;
    expect(view.title, 'Linear equations');
    expect(view.question.id, 'q1');
    expect(view.question.label, 'Question 1');
    expect(view.question.stemMd, 'Solve the equation.');
    expect(view.question.difficulty, QuestionDifficulty.medium);
    expect(
      (view.question.kind as McqKind).choices.map((c) => (c.label, c.md)),
      [
        ('A', 'One'),
        ('B', 'Two'),
      ],
    );
    expect(view.answer.selected, 'B');
    expect(view.answer.marked, isTrue);
    expect(mode.index, 0);
    expect(mode.total, 2);
    expect(mode.remaining, state.remaining);
    expect(mode.timeBudget, state.session.timeLimit);
    expect(mode.warnAt, state.session.warnAt);
    expect(mode.answered, {0});
    expect(mode.marked, {0});
    view.onSelect!('A');
    view.onMark!();
    view.onJumpTo!(1);
    view.onNext!();
    view.onToggleTimer!();
    verify(() => cubit.select('A')).called(1);
    verify(cubit.toggleMark).called(1);
    verify(() => cubit.goTo(1)).called(1);
    verify(cubit.next).called(1);
    verify(cubit.toggleTimer).called(1);
  });

  testWidgets('PRC-03: SPR answer and previous callback reach cubit', (
    tester,
  ) async {
    final cubit = _cubit(_running().copyWith(index: 1, answers: {'q2': '1/2'}));
    await _pump(tester, cubit);
    final view = _question(tester);
    expect(view.question.kind, isA<SprKind>());
    expect(view.answer.sprText, '1/2');
    view.onSprChanged!('.5');
    view.onPrev!();
    verify(() => cubit.sprChanged('.5')).called(1);
    verify(cubit.prev).called(1);
  });

  testWidgets('PRC-03: server warning threshold and hidden timer are mapped', (
    tester,
  ) async {
    await _pump(
      tester,
      _cubit(
        _running().copyWith(
          remaining: const Duration(seconds: 90),
          timerHidden: true,
        ),
      ),
      width: 1280,
    );
    final mode = _question(tester).mode as QuizMode;
    expect(mode.showsWarningBanner, isTrue);
    expect(mode.timerHidden, isTrue);
    expect(find.byType(ExamWarningBanner), findsOneWidget);
    expect(find.text('01:30'), findsOneWidget);
    expect(find.text('Timer hidden'), findsNothing);
  });

  testWidgets('PRC-03: navigator opens with answered and marked status', (
    tester,
  ) async {
    final cubit = _cubit(_running());
    await _pump(tester, cubit);
    await tester.tap(find.text('Question 1 of 2'));
    await tester.pumpAndSettle();
    expect(find.text('Linear equations questions'), findsOneWidget);
    expect(find.text('Submit quiz'), findsOneWidget);
    final grid = tester.widget<QuestionNavigatorGrid>(
      find.byType(QuestionNavigatorGrid),
    );
    expect(grid.answered, {0});
    expect(grid.marked, {0});
    await tester.tap(find.byKey(const ValueKey('nav-cell-1')));
    await tester.pumpAndSettle();
    verify(() => cubit.goTo(1)).called(1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('PRC-03: hidden timer can be shown before warning window', (
    tester,
  ) async {
    final cubit = _cubit(_running().copyWith(timerHidden: true));
    await _pump(tester, cubit, width: 1280);
    expect(find.byType(ExamWarningBanner), findsNothing);
    expect(find.text('Timer hidden'), findsOneWidget);
    await tester.tap(find.text('Show'));
    verify(cubit.toggleTimer).called(1);
  });

  testWidgets('PRC-03: autosave failure keeps answer and shows exact note', (
    tester,
  ) async {
    await _pump(
      tester,
      _cubit(
        _running().copyWith(
          saveError: const AppError(ErrorCodes.network, 'secret'),
        ),
      ),
    );
    expect(find.text('Not saved — retrying'), findsOneWidget);
    expect(_question(tester).answer.selected, 'B');
    expect(find.textContaining('secret'), findsNothing);
  });

  testWidgets('PRC-03: submit error offers retry without exposing details', (
    tester,
  ) async {
    final cubit = _cubit(
      _running().copyWith(
        submitError: const AppError(ErrorCodes.network, 'secret'),
      ),
    );
    await _pump(tester, cubit);
    expect(find.textContaining('secret'), findsNothing);
    await tester.tap(find.text('Retry submit'));
    verify(cubit.submit).called(1);
  });

  testWidgets('PRC-03: terminal save error does not promise another retry', (
    tester,
  ) async {
    await _pump(
      tester,
      _cubit(
        _running().copyWith(
          saveError: const AppError(ErrorCodes.invalidInput, 'secret'),
        ),
      ),
    );
    expect(find.text('Not saved — return to the topic'), findsOneWidget);
    expect(find.text('Not saved — retrying'), findsNothing);
    expect(find.textContaining('secret'), findsNothing);
  });

  testWidgets('PRC-03: Submit quiz requires the existing confirmation', (
    tester,
  ) async {
    final cubit = _cubit(_running().copyWith(index: 1));
    await _pump(tester, cubit);
    await tester.tap(find.text('Submit quiz'));
    await tester.pumpAndSettle();
    expect(find.text('Submit quiz?'), findsOneWidget);
    expect(
      find.text('After you submit, your answers are locked and marked.'),
      findsOneWidget,
    );
    verifyNever(cubit.submit);
    await tester.tap(find.text('Submit quiz').last);
    await tester.pumpAndSettle();
    verify(cubit.submit).called(1);
  });

  testWidgets('PRC-03: manual submission navigates with the exact report', (
    tester,
  ) async {
    final stream = StreamController<QuizState>();
    addTearDown(stream.close);
    final cubit = _cubit(_running(), stream: stream.stream);
    final router = await _pump(tester, cubit);
    stream.add(const QuizSubmitted(_passed));
    await tester.pumpAndSettle();
    expect(
      router.routeInformationProvider.value.uri.path,
      '/courses/topics/t1/quiz/result',
    );
    expect(find.text('Result destination'), findsOneWidget);
    expect(router.routerDelegate.currentConfiguration.extra, same(_passed));
  });

  testWidgets('PRC-03: result replaces quiz and back returns to topic', (
    tester,
  ) async {
    final stream = StreamController<QuizState>();
    addTearDown(stream.close);
    final cubit = _cubit(_running(), stream: stream.stream);
    final router = await _pump(tester, cubit, fromTopic: true);
    expect(router.canPop(), isTrue);
    stream.add(const QuizSubmitted(_passed));
    await tester.pumpAndSettle();
    expect(find.text('Result destination'), findsOneWidget);
    expect(router.canPop(), isTrue);
    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('Topic destination'), findsOneWidget);
    expect(find.byType(QuizView), findsNothing);
    expect(router.canPop(), isFalse);
  });

  testWidgets('PRC-03: time up replaces confirmation only after success', (
    tester,
  ) async {
    final stream = StreamController<QuizState>();
    addTearDown(stream.close);
    final cubit = _cubit(_running().copyWith(index: 1), stream: stream.stream);
    final router = await _pump(tester, cubit);
    await tester.tap(find.text('Submit quiz'));
    await tester.pumpAndSettle();
    stream.add(_running().copyWith(remaining: Duration.zero, submitting: true));
    await tester.pump();
    expect(find.text("Time's up. Linear equations submitted."), findsNothing);
    stream.add(const QuizSubmitted(_passed));
    await tester.pumpAndSettle();
    expect(find.text('Submit quiz?'), findsNothing);
    expect(find.text("Time's up. Linear equations submitted."), findsOneWidget);
    expect(find.text('Result destination'), findsNothing);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(
      router.routeInformationProvider.value.uri.path,
      '/courses/topics/t1/quiz/result',
    );
    expect(find.text("Time's up. Linear equations submitted."), findsNothing);
  });

  testWidgets('PRC-03: failed time-up submit keeps retry available', (
    tester,
  ) async {
    final stream = StreamController<QuizState>();
    addTearDown(stream.close);
    final cubit = _cubit(_running(), stream: stream.stream);
    await _pump(tester, cubit);
    stream.add(_running().copyWith(remaining: Duration.zero, submitting: true));
    await tester.pump();
    stream.add(
      _running().copyWith(
        remaining: Duration.zero,
        submitError: const AppError(ErrorCodes.network),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text("Time's up. Linear equations submitted."), findsNothing);
    await tester.tap(find.text('Retry submit'));
    verify(cubit.submit).called(1);
    stream.add(const QuizSubmitted(_passed));
    await tester.pumpAndSettle();
    expect(find.text("Time's up. Linear equations submitted."), findsOneWidget);
  });

  testWidgets('PRC-03: submitting disables answer interactions', (
    tester,
  ) async {
    await _pump(tester, _cubit(_running().copyWith(submitting: true)));
    final view = _question(tester);
    expect(view.onSelect, isNull);
    expect(view.onSprChanged, isNull);
    expect(view.onMark, isNull);
    expect(view.onJumpTo, isNull);
    expect(view.onSubmit, isNull);
  });

  testWidgets('PRC-03: blank and null answers stay unanswered in navigator', (
    tester,
  ) async {
    await _pump(
      tester,
      _cubit(
        _running().copyWith(
          answers: const {'q1': null, 'q2': '  '},
          marked: const {'q2'},
        ),
      ),
    );
    final mode = _question(tester).mode as QuizMode;
    expect(mode.answered, isEmpty);
    expect(mode.marked, {1});
  });

  for (final (code, copy) in <(String, String?)>[
    (
      ErrorCodes.practiceNeeded,
      'Complete more practice before starting this quiz.',
    ),
    (
      ErrorCodes.cooldownActive,
      'You can retake this quiz after the cooldown ends.',
    ),
    (ErrorCodes.poolExhausted, 'No quiz questions yet.'),
    (
      ErrorCodes.topicLocked,
      'This topic is locked. Pass the previous quiz first.',
    ),
    (ErrorCodes.accessExpired, 'Your access has ended. Contact your teacher.'),
    (ErrorCodes.notEnrolled, "You're not enrolled in a course yet."),
    (ErrorCodes.network, 'Check your connection and try again.'),
  ]) {
    testWidgets('PRC-03: $code shows safe copy and returns to topic', (
      tester,
    ) async {
      final router = await _pump(
        tester,
        _cubit(QuizFailed(AppError(code, 'secret database detail'))),
      );
      if (copy != null) expect(find.text(copy), findsOneWidget);
      expect(find.textContaining('secret database detail'), findsNothing);
      await tester.tap(find.text('Back to topic'));
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.path,
        '/courses/topics/t1',
      );
    });
  }

  for (final width in [360.0, 1280.0]) {
    testWidgets('PRC-03: running with both errors fits $width', (tester) async {
      await _pump(
        tester,
        _cubit(
          _running().copyWith(
            saveError: const AppError(ErrorCodes.network),
            submitError: const AppError(ErrorCodes.network),
          ),
        ),
        width: width,
      );
      expect(tester.takeException(), isNull);
    });
  }
  _resultTests();
}
