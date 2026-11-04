import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/core/theme/app_theme.dart';
import 'package:sat_east_client/core/video/video_provider.dart';
import 'package:sat_east_client/features/course_map/domain/entities/course_map.dart';
import 'package:sat_east_client/features/home/domain/entities/current_step.dart';
import 'package:sat_east_client/features/home/domain/entities/home_summary.dart';
import 'package:sat_east_client/features/home/presentation/cubit/home_cubit.dart';
import 'package:sat_east_client/features/home/presentation/cubit/home_state.dart';
import 'package:sat_east_client/features/home/presentation/screens/home_screen.dart';
import 'package:sat_east_client/features/topic/domain/entities/topic_detail.dart';
import 'package:sat_east_client/features/topic/domain/entities/topic_homework.dart';
import 'package:sat_east_client/features/topic/domain/entities/topic_note.dart';
import 'package:sat_east_client/features/topic/domain/entities/topic_video.dart';
import 'package:sat_east_client/shared/widgets/app_banner.dart';
import 'package:sat_east_client/shared/widgets/app_skeleton.dart';

class _HomeCubit extends MockCubit<HomeState> implements HomeCubit {}

const _homework = HomeworkStep(
  TopicHomework(
    state: HomeworkState.inProgress,
    total: 20,
    answered: 8,
    attemptId: 'attempt-id',
  ),
);
const _video = VideoStep(
  TopicVideo(
    assetId: 'video-id',
    title: 'Lesson',
    durationS: 100,
    provider: VideoProvider.youtube,
    pct: 0,
    lastPositionS: 0,
  ),
);
HomeReady _ready({
  CurrentStep step = _homework,
  bool firstRun = false,
  ExpiryWarning? expiry,
  String name = 'Abdelrahman',
}) => HomeReady(
  firstName: name,
  courseTitle: 'SAT Math',
  unitTitle: 'Algebra',
  topic: const ContinueTopic(
    topicId: 'topic-id',
    slug: 'linear',
    title: 'Linear equations',
    unitTitle: 'Algebra',
  ),
  topicSortLabel: '1.2',
  step: step,
  firstRun: firstRun,
  passed: firstRun ? 0 : 9,
  total: 40,
  expiry: expiry,
);

Future<({GoRouter router, _HomeCubit cubit})> _pump(
  WidgetTester tester,
  HomeState state, {
  double width = 360,
  Brightness brightness = Brightness.light,
  double textScale = 1,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 1000);
  addTearDown(tester.view.reset);
  final cubit = _HomeCubit();
  whenListen(cubit, const Stream<HomeState>.empty(), initialState: state);
  when(cubit.retry).thenAnswer((_) async {});
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => Scaffold(
          body: BlocProvider<HomeCubit>.value(
            value: cubit,
            child: const HomeView(),
          ),
        ),
      ),
      for (final path in [
        '/courses',
        '/activate',
        '/catalogue',
        '/else',
        '/courses/topics/topic-id',
        '/courses/topics/topic-id/video/video-id',
        '/courses/topics/topic-id/notes/note-id',
        '/courses/topics/topic-id/practice',
        '/courses/topics/topic-id/homework',
        '/courses/topics/topic-id/quiz',
      ])
        GoRoute(
          path: path,
          builder: (_, _) => Scaffold(body: Text('route:$path')),
        ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MaterialApp.router(
      theme: brightness == Brightness.light
          ? AppTheme.light()
          : AppTheme.dark(),
      routerConfig: router,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations: true,
          textScaler: TextScaler.linear(textScale),
        ),
        child: child!,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (router: router, cubit: cubit);
}

void main() {
  testWidgets('LRN-07: loading shows skeleton', (tester) async {
    await _pump(tester, const HomeLoading());
    expect(find.byType(AppSkeleton), findsOneWidget);
  });
  testWidgets('LRN-07: ready shows greeting step and course counts', (
    tester,
  ) async {
    await _pump(tester, HomeLoaded(_ready()));
    expect(find.text('Hi, Abdelrahman'), findsOneWidget);
    expect(find.text('SAT Math \u00b7 Algebra'), findsOneWidget);
    expect(find.text('Continue where you left off'), findsOneWidget);
    expect(find.text('1.2 Linear equations'), findsOneWidget);
    expect(find.text('Step 4 of 5 \u00b7 Homework'), findsOneWidget);
    expect(find.text('9 of 40 topics passed'), findsOneWidget);
  });
  testWidgets('LRN-07: first run welcomes and starts topic', (tester) async {
    await _pump(tester, HomeLoaded(_ready(step: _video, firstRun: true)));
    expect(find.text('Welcome, Abdelrahman'), findsOneWidget);
    expect(find.text('Start here'), findsOneWidget);
    await tester.tap(find.text('Start topic 1.2'));
    await tester.pumpAndSettle();
    expect(
      find.text('route:/courses/topics/topic-id/video/video-id'),
      findsOneWidget,
    );
  });
  for (final firstRun in [false, true]) {
    testWidgets('LRN-07: empty name greeting firstRun $firstRun', (
      tester,
    ) async {
      await _pump(
        tester,
        HomeLoaded(_ready(name: '', firstRun: firstRun, step: _video)),
      );
      expect(find.text(firstRun ? 'Welcome' : 'Hi'), findsOneWidget);
    });
  }
  testWidgets('LRN-07: finished shows course completion', (tester) async {
    await _pump(
      tester,
      const HomeLoaded(HomeFinished('Student', 'SAT Math', 40)),
    );
    expect(find.text('You finished SAT Math'), findsOneWidget);
    await tester.tap(find.text('Open contents'));
    await tester.pumpAndSettle();
    expect(find.text('route:/courses'), findsOneWidget);
  });
  testWidgets('LRN-07: expired offers activation', (tester) async {
    await _pump(tester, const HomeLoaded(HomeExpired('Student')));
    expect(
      find.text('Your access has ended. Your progress is saved.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Enter activation code'));
    await tester.pumpAndSettle();
    expect(find.text('route:/activate'), findsOneWidget);
  });
  testWidgets('LRN-07: not enrolled offers catalogue', (tester) async {
    await _pump(tester, const HomeLoaded(HomeNotEnrolled('Student')));
    expect(find.text("You're not in a course yet"), findsOneWidget);
    await tester.tap(find.text('Browse courses'));
    await tester.pumpAndSettle();
    expect(find.text('route:/catalogue'), findsOneWidget);
  });
  for (final (code, copy) in [
    (ErrorCodes.network, 'Check your connection and try again.'),
    (ErrorCodes.internal, 'Something went wrong. Try again.'),
  ]) {
    testWidgets('LRN-07: failed $code shows safe copy and Retry', (
      tester,
    ) async {
      final result = await _pump(
        tester,
        HomeFailed(AppError(code, 'private diagnostic')),
      );
      expect(find.text(copy), findsOneWidget);
      expect(find.text('private diagnostic'), findsNothing);
      await tester.tap(find.text('Retry'));
      await tester.pump();
      verify(result.cubit.retry).called(1);
    });
  }
  testWidgets('LRN-07: expiry banner shown and activates access', (
    tester,
  ) async {
    final expiry = DateTime(2026, 11, 11);
    await _pump(tester, HomeLoaded(_ready(expiry: ExpiryWarning(9, expiry))));
    final context = tester.element(find.byType(HomeView));
    final date = MaterialLocalizations.of(context).formatMediumDate(expiry);
    expect(
      find.text('Your SAT Math access ends in 9 days, on $date.'),
      findsOneWidget,
    );
    expect(find.byType(AppBanner), findsOneWidget);
    await tester.tap(find.text('Enter activation code'));
    await tester.pumpAndSettle();
    expect(find.text('route:/activate'), findsOneWidget);
  });
  testWidgets('LRN-07: expiry banner uses singular day', (tester) async {
    await _pump(
      tester,
      HomeLoaded(_ready(expiry: ExpiryWarning(1, DateTime(2026, 11, 3)))),
    );
    expect(find.textContaining('access ends in 1 day, on'), findsOneWidget);
  });
  testWidgets('LRN-07: expiry banner hidden without warning', (tester) async {
    await _pump(tester, HomeLoaded(_ready()));
    expect(find.byType(AppBanner), findsNothing);
  });
  testWidgets('LRN-07: homework line shows answered and remaining', (
    tester,
  ) async {
    await _pump(tester, HomeLoaded(_ready()));
    expect(find.text('8 answered, 12 to go'), findsOneWidget);
  });
  testWidgets('LRN-07: Continue homework navigates to homework route', (
    tester,
  ) async {
    await _pump(tester, HomeLoaded(_ready()));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(
      find.text('route:/courses/topics/topic-id/homework'),
      findsOneWidget,
    );
  });
  final steps = <(String, CurrentStep, String, String)>[
    ('video', _video, 'Watch the lesson video', 'video/video-id'),
    (
      'notes',
      const NotesStep(TopicNote(assetId: 'note-id', title: 'Notes')),
      'Read the notes',
      'notes/note-id',
    ),
    (
      'practice',
      const PracticeStep(3, 5),
      '3 of 5 practice questions',
      'practice',
    ),
    (
      'available homework',
      const HomeworkStep(
        TopicHomework(state: HomeworkState.available, total: 20),
      ),
      '20 questions',
      'homework',
    ),
    (
      'available quiz',
      const QuizStep(QuizAvailable()),
      'Take the quiz',
      'quiz',
    ),
    (
      'in progress quiz',
      const QuizStep(QuizInProgress(attemptId: 'a')),
      'Finish your quiz',
      'quiz',
    ),
  ];
  for (final (name, step, line, suffix) in steps) {
    testWidgets('LRN-07: $name copy and route', (tester) async {
      await _pump(tester, HomeLoaded(_ready(step: step)));
      expect(find.text(line), findsOneWidget);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(
        find.text('route:/courses/topics/topic-id/$suffix'),
        findsOneWidget,
      );
    });
  }
  testWidgets('LRN-07: quiz cooldown shows local time and opens topic', (
    tester,
  ) async {
    final instant = DateTime.utc(2026, 11, 3, 15, 30);
    await _pump(
      tester,
      HomeLoaded(_ready(step: QuizStep(QuizCooldown(availableAt: instant)))),
    );
    final context = tester.element(find.byType(HomeView));
    final local = instant.toLocal();
    final l10n = MaterialLocalizations.of(context);
    final time = l10n.formatTimeOfDay(
      TimeOfDay.fromDateTime(local),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );
    expect(
      find.text('Quiz opens again at ${l10n.formatMediumDate(local)} $time'),
      findsOneWidget,
    );
    await tester.tap(find.text('Open topic'));
    await tester.pumpAndSettle();
    expect(find.text('route:/courses/topics/topic-id'), findsOneWidget);
  });
  for (final quiz in [
    const QuizPracticeNeeded(count: 0, min: 5),
    const QuizHomeworkNeeded(),
  ]) {
    testWidgets('LRN-07: ${quiz.runtimeType} opens topic', (tester) async {
      await _pump(tester, HomeLoaded(_ready(step: QuizStep(quiz))));
      await tester.tap(find.widgetWithText(FilledButton, 'Open topic'));
      await tester.pumpAndSettle();
      expect(find.text('route:/courses/topics/topic-id'), findsOneWidget);
    });
  }
  testWidgets('LRN-07: Open contents navigates to courses', (tester) async {
    await _pump(tester, HomeLoaded(_ready()));
    await tester.ensureVisible(find.text('Open contents'));
    await tester.tap(find.text('Open contents'));
    await tester.pumpAndSettle();
    expect(find.text('route:/courses'), findsOneWidget);
  });
  testWidgets('LRN-07: returning home refreshes summary', (tester) async {
    final result = await _pump(tester, HomeLoaded(_ready()));
    unawaited(result.router.push<void>('/else'));
    await tester.pumpAndSettle();
    result.router.pop();
    await tester.pumpAndSettle();
    verify(result.cubit.retry).called(1);
  });
  testWidgets('LRN-07: reselecting home refreshes summary', (tester) async {
    final result = await _pump(tester, HomeLoaded(_ready()));
    result.router.go('/');
    await tester.pumpAndSettle();
    verify(result.cubit.retry).called(1);
  });
  for (final width in [360.0, 1280.0]) {
    for (final brightness in Brightness.values) {
      testWidgets('LRN-07: no overflow at $width ${brightness.name}', (
        tester,
      ) async {
        await _pump(
          tester,
          HomeLoaded(_ready(expiry: ExpiryWarning(9, DateTime(2026, 11, 11)))),
          width: width,
          brightness: brightness,
          textScale: 2,
        );
        await tester.ensureVisible(find.text('Open contents'));
        expect(tester.takeException(), isNull);
      });
    }
  }
}
