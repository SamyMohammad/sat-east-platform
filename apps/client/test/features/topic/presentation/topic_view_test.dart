import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sat_east_client/core/di/injection.dart';
import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/core/theme/app_hues.dart';
import 'package:sat_east_client/core/theme/app_theme.dart';
import 'package:sat_east_client/features/quiz/presentation/quiz_entry.dart';
import 'package:sat_east_client/features/topic/domain/entities/topic_detail.dart';
import 'package:sat_east_client/features/topic/presentation/cubit/topic_cubit.dart';
import 'package:sat_east_client/features/topic/presentation/cubit/topic_state.dart';
import 'package:sat_east_client/features/topic/presentation/screens/topic_screen.dart';
import 'package:sat_east_client/shared/widgets/app_skeleton.dart';
import 'package:sat_east_client/shared/widgets/icon_tile.dart';

class _Cubit extends MockCubit<TopicState> implements TopicCubit {}

TopicLoaded _loaded(QuizStatus quiz) => TopicLoaded(
  TopicDetail(
    id: 't1',
    title: 'Linear equations',
    sortLabel: '1.1',
    status: TopicStatus.open,
    practiceCount: 4,
    practiceMin: 10,
    quiz: quiz,
  ),
);

Future<(_Cubit, GoRouter)> _pump(
  WidgetTester tester,
  TopicState state, {
  double width = 360,
  double scale = 1,
}) async {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final cubit = _Cubit();
  whenListen(cubit, const Stream<TopicState>.empty(), initialState: state);
  when(() => cubit.load(any())).thenAnswer((_) async {});
  final router = GoRouter(
    initialLocation: '/courses/topics/t1',
    routes: [
      GoRoute(
        path: '/courses/topics/t1',
        builder: (_, _) => Scaffold(
          body: BlocProvider<TopicCubit>.value(
            value: cubit,
            child: const TopicView(topicId: 't1'),
          ),
        ),
      ),
      GoRoute(
        path: '/courses/topics/t1/practice',
        builder: (_, _) => const Scaffold(body: Text('Practice destination')),
      ),
      GoRoute(
        path: '/courses/topics/t1/quiz',
        builder: (_, _) => const Scaffold(body: Text('Quiz destination')),
      ),
      GoRoute(
        path: '/courses',
        builder: (_, _) => const Scaffold(body: Text('Course destination')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MaterialApp.router(
      theme: AppTheme.light(),
      routerConfig: router,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  return (cubit, router);
}

Finder _button(String text) => find.ancestor(
  of: find.text(text),
  matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
);

void main() {
  testWidgets('topic_step_rows_have_distinct_hues_at_360_text2x', (
    tester,
  ) async {
    await _pump(tester, _loaded(const QuizAvailable()), scale: 2);
    final tiles = tester.widgetList<IconTile>(find.byType(IconTile)).toList();
    expect(tiles.map((tile) => tile.hue), [SubjectHue.violet, SubjectHue.rose]);
    expect(
      find.ancestor(
        of: find.byType(IconTile).first,
        matching: find.byType(Row),
      ),
      findsWidgets,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('PRC-03: screen starts one cubit and closes it on removal', (
    tester,
  ) async {
    final cubit = _Cubit();
    whenListen(
      cubit,
      const Stream<TopicState>.empty(),
      initialState: const TopicLoading(),
    );
    when(() => cubit.load(any())).thenAnswer((_) async {});
    when(cubit.close).thenAnswer((_) async {});
    var created = 0;
    getIt.registerFactory<TopicCubit>(() {
      created++;
      return cubit;
    });
    addTearDown(() => getIt.unregister<TopicCubit>());
    final router = GoRouter(
      initialLocation: '/courses/topics/t1',
      routes: [
        GoRoute(
          path: '/courses/topics/t1',
          builder: (_, _) => const Scaffold(body: TopicScreen(topicId: 't1')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        theme: AppTheme.light(),
        routerConfig: router,
      ),
    );
    await tester.pump();
    expect(created, 1);
    verify(() => cubit.load('t1')).called(1);
    await tester.pumpWidget(const SizedBox.shrink());
    verify(cubit.close).called(1);
  });

  testWidgets('PRC-03: loading renders skeleton', (tester) async {
    await _pump(tester, const TopicLoading());
    expect(find.byType(AppSkeleton), findsOneWidget);
  });

  for (final width in [360.0, 1280.0]) {
    for (final (name, quiz) in <(String, QuizStatus)>[
      ('available', const QuizAvailable()),
      ('in progress', const QuizInProgress(attemptId: 'a1')),
      ('practice needed', const QuizPracticeNeeded(count: 4, min: 10)),
      (
        'cooldown',
        QuizCooldown(availableAt: DateTime.utc(2026, 10, 18, 12, 30)),
      ),
    ]) {
      testWidgets('PRC-03: $name fits $width', (tester) async {
        await _pump(tester, _loaded(quiz), width: width);
        expect(find.textContaining('Linear equations'), findsWidgets);
        expect(find.text('4 of 10 practice questions done'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final (quiz, label) in <(QuizStatus, String)>[
    (const QuizAvailable(), 'Start quiz'),
    (const QuizInProgress(attemptId: 'a1'), 'Resume quiz'),
  ]) {
    testWidgets('PRC-03: $label navigates to quiz', (tester) async {
      await _pump(tester, _loaded(quiz));
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(find.text('Quiz destination'), findsOneWidget);
      expect(
        GoRouterState.of(tester.element(find.text('Quiz destination'))).extra,
        QuizEntry.startOrResume,
      );
    });
  }

  testWidgets('PRC-03: practice button navigates to practice', (tester) async {
    await _pump(tester, _loaded(const QuizAvailable()));
    await tester.tap(_button('Practice'));
    await tester.pumpAndSettle();
    expect(find.text('Practice destination'), findsOneWidget);
  });

  testWidgets('PRC-03: practice gate disables quiz with exact remaining copy', (
    tester,
  ) async {
    await _pump(tester, _loaded(const QuizPracticeNeeded(count: 4, min: 10)));
    expect(
      find.text('Answer 6 more practice questions to unlock the quiz.'),
      findsOneWidget,
    );
    expect(
      tester.widget<ButtonStyleButton>(_button('Start quiz')).onPressed,
      isNull,
    );
  });

  testWidgets('PRC-03: cooldown uses localized local date and time', (
    tester,
  ) async {
    final local = DateTime.utc(2026, 10, 18, 12, 30).toLocal();
    await _pump(tester, _loaded(QuizCooldown(availableAt: local)));
    final context = tester.element(find.byType(TopicView));
    final l10n = MaterialLocalizations.of(context);
    final date = l10n.formatMediumDate(local);
    final time = l10n.formatTimeOfDay(
      TimeOfDay.fromDateTime(local),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );
    final value = '$date $time';
    expect(find.text('You can retake the quiz after $value.'), findsOneWidget);
    expect(
      tester.widget<ButtonStyleButton>(_button('Start quiz')).onPressed,
      isNull,
    );
  });

  testWidgets('PRC-03: prior pass and best score stay visible on retake', (
    tester,
  ) async {
    await _pump(
      tester,
      _loaded(const QuizAvailable(bestScorePct: 83.33, passed: true)),
    );
    expect(find.text('Best score 83.33%'), findsOneWidget);
    expect(find.text('Passed'), findsOneWidget);
    expect(
      tester.widget<ButtonStyleButton>(_button('Start quiz')).onPressed,
      isNotNull,
    );
  });

  for (final (code, copy) in [
    (
      ErrorCodes.topicLocked,
      'This topic is locked. Pass the previous quiz first.',
    ),
    (ErrorCodes.accessExpired, 'Your access has ended. Contact your teacher.'),
    (ErrorCodes.notEnrolled, "You're not enrolled in a course yet."),
    (ErrorCodes.network, 'Check your connection and try again.'),
    (ErrorCodes.internal, 'Something went wrong. Try again.'),
  ]) {
    testWidgets('PRC-03: $code uses safe shared error copy', (tester) async {
      await _pump(
        tester,
        TopicFailed(AppError(code, 'secret database detail')),
      );
      expect(find.text(copy), findsOneWidget);
      expect(find.textContaining('secret database detail'), findsNothing);
    });
  }

  testWidgets('PRC-03: retry reloads current topic', (tester) async {
    final (cubit, _) = await _pump(
      tester,
      const TopicFailed(AppError(ErrorCodes.network)),
    );
    await tester.tap(find.text('Retry'));
    verify(() => cubit.load('t1')).called(1);
  });
}
