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
import 'package:sat_east_client/core/router/app_router.dart';
import 'package:sat_east_client/core/theme/app_theme.dart';
import 'package:sat_east_client/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:sat_east_client/features/auth/presentation/cubit/auth_state.dart';
import 'package:sat_east_client/features/auth/presentation/screens/account_screen.dart';
import 'package:sat_east_client/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:sat_east_client/features/auth/presentation/screens/set_new_password_screen.dart';
import 'package:sat_east_client/features/design_gallery/presentation/gallery_screen.dart';
import 'package:sat_east_client/features/practice/presentation/screens/practice_screen.dart';
import 'package:sat_east_client/features/quiz/domain/entities/quiz.dart';
import 'package:sat_east_client/features/quiz/presentation/cubit/quiz_cubit.dart';
import 'package:sat_east_client/features/quiz/presentation/cubit/quiz_state.dart';
import 'package:sat_east_client/features/quiz/presentation/quiz_entry.dart';
import 'package:sat_east_client/features/quiz/presentation/screens/quiz_result_screen.dart';
import 'package:sat_east_client/features/quiz/presentation/screens/quiz_screen.dart';
import 'package:sat_east_client/features/topic/presentation/cubit/topic_state.dart';
import 'package:sat_east_client/features/topic/presentation/screens/topic_screen.dart';
import 'package:sat_east_client/shared/widgets/question_view/question_view.dart';

import '../../features/auth/presentation/screens/auth_screen_harness.dart'
    as auth_screens;
import 'fake_account_cubit.dart';
import 'fake_course_map_cubit.dart';
import 'fake_practice_cubit.dart';
import 'fake_topic_cubit.dart';

part 'fake_quiz_cubit.dart';

void main() {
  setUp(registerFakeAccountCubit);
  tearDown(unregisterFakeAccountCubit);
  testWidgets('S-34: Profile route builds My account', (tester) async {
    _viewport(tester, 360);
    final router = createRouter(initialLocation: AppRoutes.profile);
    addTearDown(router.dispose);
    await _pumpRouter(tester, router);
    expect(find.byType(AccountScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  for (final width in [360.0, 1280.0]) {
    for (final (path, type, state) in [
      (AppRoutes.forgotPassword, ForgotPasswordScreen, const AuthSignedOut()),
      (AppRoutes.resetPassword, SetNewPasswordScreen, const AuthRecovery()),
    ]) {
      testWidgets('S-03: $path builds its auth screen at $width', (
        tester,
      ) async {
        _viewport(tester, width);
        final router = createRouter(initialLocation: path);
        addTearDown(router.dispose);
        await tester.pumpWidget(
          BlocProvider<AuthCubit>.value(
            value: auth_screens.mockCubit(state),
            child: MaterialApp.router(
              theme: AppTheme.light(),
              routerConfig: router,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(type), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
  final destinations = [
    (AppRoutes.home, 'Home'),
    (AppRoutes.courses, 'Courses'),
    (AppRoutes.skills, 'Skills'),
    (AppRoutes.mockExams, 'Mock exams'),
    (AppRoutes.profile, 'Profile'),
  ];

  setUp(registerFakeTopicCubit);
  tearDown(unregisterFakeTopicCubit);
  setUp(registerFakeCourseMapCubit);
  tearDown(unregisterFakeCourseMapCubit);
  setUp(registerFakePracticeCubit);
  tearDown(unregisterFakePracticeCubit);
  setUp(registerFakeQuizCubit);
  tearDown(unregisterFakeQuizCubit);

  const passedReport = QuizReport(
    scoreRaw: 9,
    scoreTotal: 12,
    scorePct: 75,
    passMark: 70,
    passed: true,
    nextTopic: null,
    retakeAt: null,
  );
  for (final (page, path, extra) in <(String, String, Object?)>[
    ('topic', AppRoutes.topic('x'), null),
    ('practice', AppRoutes.practice('x'), null),
    ('quiz', AppRoutes.quiz('x'), QuizEntry.startOrResume),
    ('quiz result', AppRoutes.quizResult('x'), passedReport),
  ]) {
    for (final back in ['pop', 'go', 'Courses tab']) {
      testWidgets('L-1: staging courses reloads after $page via $back', (
        tester,
      ) async {
        var loads = 0;
        await registerFakeCourseMapCubit(onLoad: () => loads++);
        _viewport(tester, 1280);
        final router = createRouter(initialLocation: AppRoutes.courses);
        addTearDown(router.dispose);
        await _pumpRouter(tester, router);
        expect(loads, 1);
        unawaited(router.push<void>(path, extra: extra));
        await tester.pumpAndSettle();
        expect(
          router.routerDelegate.currentConfiguration.last.matchedLocation,
          path,
        );
        if (page == 'quiz result') {
          expect(find.text('Quiz passed'), findsOneWidget);
        }
        expect(loads, 1);
        if (back == 'pop') {
          router.pop();
        } else if (back == 'go') {
          router.go(AppRoutes.courses);
        } else {
          await tester.tap(
            find.descendant(
              of: _navigationFinder(),
              matching: find.text('Courses'),
            ),
          );
        }
        await tester.pumpAndSettle();
        expect(
          router.routerDelegate.currentConfiguration.last.matchedLocation,
          AppRoutes.courses,
        );
        expect(loads, 2);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }

  testWidgets('L-1: staging courses reloads after switching shell branches', (
    tester,
  ) async {
    var loads = 0;
    await registerFakeCourseMapCubit(onLoad: () => loads++);
    _viewport(tester, 1280);
    final router = createRouter(initialLocation: AppRoutes.courses);
    addTearDown(router.dispose);
    await _pumpRouter(tester, router);
    router.go(AppRoutes.skills);
    await tester.pumpAndSettle();
    expect(loads, 1);
    await tester.tap(
      find.descendant(
        of: _navigationFinder(),
        matching: find.text('Courses'),
      ),
    );
    await tester.pumpAndSettle();
    expect(loads, 2);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('L-1: staging reselecting visible Courses reloads the map', (
    tester,
  ) async {
    var loads = 0;
    await registerFakeCourseMapCubit(onLoad: () => loads++);
    _viewport(tester, 1280);
    final router = createRouter(initialLocation: AppRoutes.courses);
    addTearDown(router.dispose);
    await _pumpRouter(tester, router);
    expect(loads, 1);
    await tester.tap(
      find.descendant(
        of: _navigationFinder(),
        matching: find.text('Courses'),
      ),
    );
    await tester.pumpAndSettle();
    expect(loads, 2);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('PRC-01: staging cold topic Practice button uses loaded title', (
    tester,
  ) async {
    _viewport(tester, 1280);
    final router = createRouter(initialLocation: AppRoutes.topic('t1'));
    addTearDown(router.dispose);
    await _pumpRouter(tester, router);
    await tester.tap(
      find.ancestor(
        of: find.text('Practice'),
        matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<QuestionView>(find.byType(QuestionView)).title,
      'Linear equations',
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('PRC-01: staging topic Practice button preserves topic title', (
    tester,
  ) async {
    _viewport(tester, 1280);
    final router = createRouter();
    addTearDown(router.dispose);
    await _pumpRouter(tester, router);
    router.go(AppRoutes.topic('x'), extra: 'Linear equations');
    await tester.pumpAndSettle();
    await tester.tap(
      find.ancestor(
        of: find.text('Practice'),
        matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<QuestionView>(find.byType(QuestionView)).title,
      'Linear equations',
    );
    expect(find.text('Linear equations'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('F-4: staging cold courses link highlights Courses sidebar', (
    tester,
  ) async {
    _viewport(tester, 1280);
    final router = createRouter(initialLocation: AppRoutes.courses);
    addTearDown(router.dispose);
    await _pumpRouter(tester, router);
    expect(_selectedIndex(tester), 1);
    expect(
      find.descendant(of: _navigationFinder(), matching: find.text('Courses')),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('PRC-03: quiz result helper preserves the topic ID', () {
    expect(AppRoutes.quizResult('x'), '/courses/topics/x/quiz/result');
  });

  for (final width in [360.0, 1280.0]) {
    testWidgets('PRC-03: cold quiz route returns to its topic at $width', (
      tester,
    ) async {
      var started = '';
      await registerFakeQuizCubit(onStart: (id) => started = id);
      _viewport(tester, width);
      final router = createRouter(initialLocation: AppRoutes.quiz('x'));
      addTearDown(router.dispose);
      await _pumpRouter(tester, router);
      expect(find.byType(QuizScreen), findsNothing);
      expect(find.byType(TopicScreen), findsOneWidget);
      expect(
        router.routeInformationProvider.value.uri.path,
        AppRoutes.topic('x'),
      );
      expect(started, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('PRC-03: explicit quiz entry starts its topic at $width', (
      tester,
    ) async {
      var started = '';
      await registerFakeQuizCubit(onStart: (id) => started = id);
      _viewport(tester, width);
      final router = createRouter(initialLocation: AppRoutes.topic('x'));
      addTearDown(router.dispose);
      await _pumpRouter(tester, router);
      unawaited(
        router.push<void>(AppRoutes.quiz('x'), extra: QuizEntry.startOrResume),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<QuizScreen>(find.byType(QuizScreen)).topicId, 'x');
      expect(started, 'x');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('PRC-03: quiz result route accepts its report at $width', (
      tester,
    ) async {
      const report = QuizReport(
        scoreRaw: 9,
        scoreTotal: 12,
        scorePct: 75,
        passMark: 70,
        passed: true,
        nextTopic: null,
        retakeAt: null,
      );
      _viewport(tester, width);
      final router = createRouter();
      addTearDown(router.dispose);
      await _pumpRouter(tester, router);
      router.go(AppRoutes.quizResult('x'), extra: report);
      await tester.pumpAndSettle();
      final screen = tester.widget<QuizResultScreen>(
        find.byType(QuizResultScreen),
      );
      expect(screen.topicId, 'x');
      expect(screen.report, same(report));
      expect(find.text('Quiz passed'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('PRC-03: wrong quiz extra returns to topic without starting', (
    tester,
  ) async {
    var starts = 0;
    await registerFakeQuizCubit(onStart: (_) => starts++);
    _viewport(tester, 360);
    final router = createRouter();
    addTearDown(router.dispose);
    await _pumpRouter(tester, router);
    router.go(AppRoutes.quiz('x'), extra: 'start');
    await tester.pumpAndSettle();
    expect(find.byType(TopicScreen), findsOneWidget);
    expect(find.byType(QuizScreen), findsNothing);
    expect(starts, 0);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('PRC-03: cold result link returns to the topic', (tester) async {
    _viewport(tester, 360);
    final router = createRouter(initialLocation: AppRoutes.quizResult('x'));
    addTearDown(router.dispose);
    await _pumpRouter(tester, router);
    expect(
      router.routeInformationProvider.value.uri.path,
      AppRoutes.topic('x'),
    );
    expect(find.byType(TopicScreen), findsOneWidget);
    expect(find.byType(QuizScreen), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('PRC-03: wrong result extra returns to the topic', (
    tester,
  ) async {
    _viewport(tester, 360);
    final router = createRouter();
    addTearDown(router.dispose);
    await _pumpRouter(tester, router);
    router.go(AppRoutes.quizResult('x'), extra: 'not a report');
    await tester.pumpAndSettle();
    expect(
      router.routeInformationProvider.value.uri.path,
      AppRoutes.topic('x'),
    );
    expect(find.byType(TopicScreen), findsOneWidget);
    expect(find.byType(QuizResultScreen), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final width in [360.0, 768.0, 1280.0]) {
    for (var index = 0; index < destinations.length; index++) {
      final (path, label) = destinations[index];
      testWidgets('F-4: direct $path link selects $label at $width', (
        tester,
      ) async {
        _viewport(tester, width);
        final router = createRouter(initialLocation: path);
        try {
          await _pumpRouter(tester, router);
          expect(router.routeInformationProvider.value.uri.path, path);
          expect(_selectedIndex(tester), index);
          expect(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          router.dispose();
        }
      });
    }

    testWidgets('F-4: navigation taps change production routes at $width', (
      tester,
    ) async {
      _viewport(tester, width);
      final router = createRouter();
      try {
        await _pumpRouter(tester, router);
        for (var index = 0; index < destinations.length; index++) {
          final (path, label) = destinations[index];
          final target = find.descendant(
            of: _navigationFinder(),
            matching: find.text(label),
          );
          await tester.ensureVisible(target);
          await tester.tap(target);
          await tester.pumpAndSettle();
          expect(router.routeInformationProvider.value.uri.path, path);
          expect(_selectedIndex(tester), index);
        }
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        router.dispose();
      }
    });
  }

  testWidgets('F-4: resize preserves the production deep link and selection', (
    tester,
  ) async {
    _viewport(tester, 360);
    final router = createRouter(initialLocation: AppRoutes.mockExams);
    try {
      await _pumpRouter(tester, router);
      for (final width in [768.0, 1280.0, 360.0]) {
        tester.view.physicalSize = Size(width, 800);
        await tester.pumpAndSettle();
        expect(
          router.routeInformationProvider.value.uri.path,
          AppRoutes.mockExams,
        );
        expect(_selectedIndex(tester), 3);
        expect(tester.takeException(), isNull);
      }
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      router.dispose();
    }
  });

  testWidgets('PRC-01: /courses/topics/x/practice opens practice cold', (
    tester,
  ) async {
    _viewport(tester, 1280);
    final router = createRouter(initialLocation: AppRoutes.practice('x'));
    try {
      await _pumpRouter(tester, router);
      final screen = tester.widget<PracticeScreen>(find.byType(PracticeScreen));
      expect(screen.topicId, 'x');
      expect(screen.title, isNull);
      expect(
        tester.widget<QuestionView>(find.byType(QuestionView)).title,
        'Practice',
      );
      expect(find.text('Solve the equation.'), findsOneWidget);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      router.dispose();
    }
  });

  testWidgets(
    'PRC-01: non-string topic extra uses the practice screen default',
    (
      tester,
    ) async {
      _viewport(tester, 1280);
      final router = createRouter();
      try {
        await _pumpRouter(tester, router);
        router.go(AppRoutes.practice('x'), extra: 42);
        await tester.pumpAndSettle();
        expect(
          tester.widget<PracticeScreen>(find.byType(PracticeScreen)).title,
          isNull,
        );
        expect(
          tester.widget<QuestionView>(find.byType(QuestionView)).title,
          'Practice',
        );
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        router.dispose();
      }
    },
  );

  for (final (width, scale) in [
    (360.0, 1.0),
    (1280.0, 1.0),
    (360.0, 2.0),
    (1280.0, 2.0),
  ]) {
    testWidgets('PRC-01: practice route fits $width at ${scale}x text scale', (
      tester,
    ) async {
      _viewport(tester, width);
      final router = createRouter(initialLocation: AppRoutes.practice('x'));
      try {
        await tester.pumpWidget(
          MaterialApp.router(
            theme: AppTheme.light(),
            routerConfig: router,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(scale),
              ),
              child: child!,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(PracticeScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        router.dispose();
      }
    });
  }

  testWidgets('PRC-03: locked topic cold link shows access copy', (
    tester,
  ) async {
    await registerFakeTopicCubit(
      state: const TopicFailed(AppError(ErrorCodes.topicLocked)),
    );
    _viewport(tester, 360);
    final router = createRouter(initialLocation: AppRoutes.topic('locked'));
    try {
      await _pumpRouter(tester, router);
      expect(
        find.text('This topic is locked. Pass the previous quiz first.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      router.dispose();
    }
  });

  testWidgets('PRC-03: navigating to a topic passes its title extra', (
    tester,
  ) async {
    _viewport(tester, 1280);
    final router = createRouter();
    try {
      await _pumpRouter(tester, router);
      router.go(AppRoutes.topic('x'), extra: 'Systems');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        tester.widget<TopicScreen>(find.byType(TopicScreen)).title,
        'Systems',
      );
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      router.dispose();
    }
  });

  test(
    'PRC-03: route helpers preserve topic, practice and future quiz paths',
    () {
      expect(AppRoutes.topic('x'), '/courses/topics/x');
      expect(AppRoutes.practice('x'), '/courses/topics/x/practice');
      expect(AppRoutes.quiz('x'), '/courses/topics/x/quiz');
    },
  );

  testWidgets(
    'PRC-03: cold topic route opens TopicScreen without title extra',
    (tester) async {
      _viewport(tester, 360);
      final router = createRouter(initialLocation: AppRoutes.topic('x'));
      addTearDown(router.dispose);
      await _pumpRouter(tester, router);
      final screen = tester.widget<TopicScreen>(find.byType(TopicScreen));
      expect(screen.topicId, 'x');
      expect(screen.title, isNull);
      expect(find.byType(PracticeScreen), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('PRC-03: non-string topic extra is ignored', (tester) async {
    _viewport(tester, 360);
    final router = createRouter();
    addTearDown(router.dispose);
    await _pumpRouter(tester, router);
    router.go(AppRoutes.topic('x'), extra: 42);
    await tester.pumpAndSettle();
    expect(tester.widget<TopicScreen>(find.byType(TopicScreen)).title, isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final back in ['pop', 'go']) {
    testWidgets('PRC-03: topic reloads when practice returns via $back', (
      tester,
    ) async {
      var loads = 0;
      await registerFakeTopicCubit(onLoad: (_) => loads++);
      _viewport(tester, 1280);
      final router = createRouter(initialLocation: AppRoutes.topic('t1'));
      addTearDown(router.dispose);
      await _pumpRouter(tester, router);
      expect(loads, 1);
      final practiceButton = find.ancestor(
        of: find.text('Practice'),
        matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
      );
      await tester.tap(practiceButton);
      await tester.pumpAndSettle();
      expect(find.byType(PracticeScreen), findsOneWidget);
      if (back == 'pop') {
        router.pop();
      } else {
        router.go(AppRoutes.topic('t1'));
      }
      await tester.pumpAndSettle();
      expect(find.byType(TopicScreen), findsOneWidget);
      expect(loads, 2);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('F-4: /gallery is routed by default in the dev flavor', (
    tester,
  ) async {
    _viewport(tester, 1280);
    final router = createRouter(initialLocation: AppRoutes.gallery);
    try {
      await tester.pumpWidget(
        MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(GalleryScreen), findsOneWidget);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      router.dispose();
    }
  });

  testWidgets('F-4: /gallery is not routed when includeGallery is false', (
    tester,
  ) async {
    _viewport(tester, 1280);
    final router = createRouter(
      initialLocation: AppRoutes.gallery,
      includeGallery: false,
    );
    try {
      await _pumpRouter(tester, router);
      expect(find.byType(GalleryScreen), findsNothing);
      // go_router shows its error page; no exception may escape.
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      router.dispose();
    }
  });

  testWidgets('F-4: /gallery shows the gallery when includeGallery is true', (
    tester,
  ) async {
    _viewport(tester, 1280);
    final router = createRouter(
      initialLocation: AppRoutes.gallery,
      includeGallery: true,
    );
    try {
      await tester.pumpWidget(
        MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(GalleryScreen), findsOneWidget);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      router.dispose();
    }
  });

  test('P1-2: createRouter asserts that refresh requires auth', () {
    expect(
      () => createRouter(refresh: ValueNotifier<int>(0)),
      throwsAssertionError,
    );
  });
}

void _viewport(WidgetTester tester, double width) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 800);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

Future<void> _pumpRouter(WidgetTester tester, GoRouter router) async {
  await tester.pumpWidget(
    MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
  );
  await tester.pumpAndSettle();
}

Finder _navigationFinder() => find.byWidgetPredicate(
  (widget) =>
      widget is NavigationBar ||
      widget is NavigationRail ||
      widget is NavigationDrawer,
);

int? _selectedIndex(WidgetTester tester) =>
    switch (tester.widget<Widget>(_navigationFinder())) {
      NavigationBar(:final selectedIndex) => selectedIndex,
      NavigationRail(:final selectedIndex) => selectedIndex,
      NavigationDrawer(:final selectedIndex) => selectedIndex,
      _ => throw StateError('Expected native navigation'),
    };
