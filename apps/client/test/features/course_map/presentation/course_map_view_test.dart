import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/core/theme/app_hues.dart';
import 'package:sat_east_client/core/theme/app_icons.dart';
import 'package:sat_east_client/core/theme/app_theme.dart';
import 'package:sat_east_client/features/course_map/domain/entities/course_map.dart';
import 'package:sat_east_client/features/course_map/presentation/cubit/course_map_cubit.dart';
import 'package:sat_east_client/features/course_map/presentation/cubit/course_map_state.dart';
import 'package:sat_east_client/features/course_map/presentation/screens/course_map_screen.dart';
import 'package:sat_east_client/features/course_map/presentation/widgets/topic_row.dart';
import 'package:sat_east_client/shared/widgets/app_skeleton.dart';
import 'package:sat_east_client/shared/widgets/topic_number_tile.dart';

import '../course_map_fixtures.dart';

Future<void> _pump(
  WidgetTester tester,
  CourseMapState state, {
  Size size = const Size(360, 800),
  FakeCourseMapCubit? cubit,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final c = cubit ?? courseMapCubit(state);
  final router = GoRouter(
    initialLocation: '/courses',
    routes: [
      GoRoute(
        path: '/catalogue',
        builder: (context, _) => const Scaffold(body: Text('catalogue page')),
      ),
      GoRoute(
        path: '/activate',
        builder: (context, _) => const Scaffold(body: Text('activation form')),
      ),
      GoRoute(
        path: '/courses',
        builder: (context, _) => Scaffold(
          body: BlocProvider<CourseMapCubit>.value(
            value: c,
            child: const CourseMapView(),
          ),
        ),
        routes: [
          GoRoute(
            path: 'topics/:id',
            builder: (context, s) =>
                Scaffold(body: Text('topic:${s.pathParameters['id']}')),
          ),
        ],
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
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  testWidgets('cancelled_unlock_does_not_acknowledge_new_refresh', (
    tester,
  ) async {
    var first = 0;
    var replacement = 0;
    Widget row({required bool active, required VoidCallback onComplete}) =>
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: TopicRow(
              topic: openMapTopic,
              justUnlocked: active,
              onUnlockComplete: onComplete,
            ),
          ),
        );
    await tester.pumpWidget(row(active: true, onComplete: () => first++));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpWidget(
      row(active: false, onComplete: () => replacement++),
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    expect(first, 0);
    expect(replacement, 0);
    expect(find.byKey(const ValueKey('unlock-lock')), findsNothing);
  });

  testWidgets('map_topic_tiles_follow_unit_hues', (tester) async {
    await _pump(tester, CourseMapLoaded(courseMapFixture()));
    expect(
      tester
          .widgetList<TopicNumberTile>(find.byType(TopicNumberTile))
          .map((tile) => tile.hue),
      [SubjectHue.blue, SubjectHue.blue, SubjectHue.teal],
    );
  });

  testWidgets('map_rows_show_number_tile_and_outline_only_the_open_row', (
    tester,
  ) async {
    await _pump(tester, CourseMapLoaded(courseMapFixture()));
    expect(find.byIcon(AppIcons.topic), findsNothing);
    for (final number in ['1.1', '1.2', '2.1']) {
      expect(
        find.descendant(
          of: find.byType(TopicNumberTile),
          matching: find.text(number),
        ),
        findsOneWidget,
      );
    }
    final open = tester.widget<Container>(
      find
          .ancestor(
            of: find.text('Systems'),
            matching: find.byType(Container),
          )
          .first,
    );
    final decoration = open.decoration! as BoxDecoration;
    final border = decoration.border! as Border;
    expect(border.isUniform, isTrue);
    expect(border.top.width, 1);
    expect(decoration.borderRadius, BorderRadius.circular(12));
  });

  testWidgets('unlock_reduced_motion_shows_open_state', (tester) async {
    var acknowledged = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: TopicRow(
              topic: openMapTopic,
              justUnlocked: true,
              hue: SubjectHue.teal,
              connectFromPrevious: true,
              onUnlockComplete: () => acknowledged++,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Open'), findsOneWidget);
    expect(find.byKey(const ValueKey('unlock-lock')), findsNothing);
    expect(acknowledged, 1);
    expect(tester.binding.transientCallbackCount, 0);
  });
  testWidgets('unlock_acknowledges_after_signature_animation', (tester) async {
    var acknowledged = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: TopicRow(
            topic: openMapTopic,
            justUnlocked: true,
            connectFromPrevious: true,
            onUnlockComplete: () => acknowledged++,
          ),
        ),
      ),
    );
    expect(find.byKey(const ValueKey('unlock-lock')), findsOneWidget);
    expect(acknowledged, 0);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(acknowledged, 0);
    await tester.pump(const Duration(milliseconds: 251));
    await tester.pump();
    expect(find.byKey(const ValueKey('unlock-lock')), findsNothing);
    expect(acknowledged, 1);
  });
  for (final brightness in Brightness.values) {
    testWidgets('map_states_${brightness.name}_360_text2x', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: brightness == Brightness.light
              ? AppTheme.light()
              : AppTheme.dark(),
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(
              body: SizedBox(
                width: 360,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      for (final topic in [
                        completedMapTopic,
                        openMapTopic,
                        lockedMapTopic,
                      ])
                        TopicRow(topic: topic),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.text('Completed'), findsOneWidget);
      expect(find.text('Open'), findsOneWidget);
      expect(find.text('Locked'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('PAY-01: unenrolled student can browse courses', (tester) async {
    await _pump(
      tester,
      const CourseMapFailed(AppError(ErrorCodes.notEnrolled)),
    );
    expect(find.text('Enter activation code'), findsOneWidget);
    await tester.tap(find.text('Browse courses'));
    await tester.pumpAndSettle();
    expect(find.text('catalogue page'), findsOneWidget);
  });
  for (final (name, size) in [
    ('360x800', const Size(360, 800)),
    ('1280x800', const Size(1280, 800)),
  ]) {
    testWidgets('L-1: loaded map renders without overflow at $name', (
      tester,
    ) async {
      await _pump(
        tester,
        CourseMapLoaded(courseMapFixture(continueTopic: continueMapTopic)),
        size: size,
      );
      expect(find.text('SAT Math'), findsOneWidget);
      expect(find.text('Algebra'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('L-1: loading shows the skeleton', (tester) async {
    await _pump(tester, const CourseMapLoading());
    expect(find.byType(AppSkeleton), findsOneWidget);
  });

  testWidgets('L-1: rows expose status in their semantics label', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, CourseMapLoaded(courseMapFixture()));
    expect(
      find.bySemanticsLabel('1.1 Linear equations, Completed, Free'),
      findsOne,
    );
    expect(find.bySemanticsLabel('1.2 Systems, Open'), findsOne);
    expect(
      find.bySemanticsLabel(
        '2.1 Quadratics, Locked, Pass the Systems quiz to unlock',
      ),
      findsOne,
    );
    handle.dispose();
  });

  testWidgets('L-1: row states show check, lock, free chip and lock line', (
    tester,
  ) async {
    await _pump(tester, CourseMapLoaded(courseMapFixture()));
    expect(find.byIcon(AppIcons.correct), findsOneWidget);
    expect(find.byIcon(AppIcons.locked), findsOneWidget);
    expect(find.byIcon(AppIcons.next), findsNWidgets(2));
    expect(find.text('Free'), findsOneWidget);
    expect(find.text('Pass the Systems quiz to unlock'), findsOneWidget);
  });

  testWidgets('L-1: units without a title render no header', (tester) async {
    await _pump(
      tester,
      CourseMapLoaded(
        courseMapFixture(
          units: const [
            MapUnit(title: null, topics: [openMapTopic]),
          ],
        ),
      ),
    );
    expect(find.text('Systems'), findsOneWidget);
    expect(find.text('Algebra'), findsNothing);
  });

  testWidgets('L-1: tapping a locked row does not navigate', (tester) async {
    await _pump(tester, CourseMapLoaded(courseMapFixture()));
    await tester.tap(find.text('Quadratics'));
    await tester.pumpAndSettle();
    expect(find.text('topic:t3'), findsNothing);
    expect(find.text('SAT Math'), findsOneWidget);
  });

  testWidgets('L-1: tapping a completed row goes to its topic', (tester) async {
    await _pump(tester, CourseMapLoaded(courseMapFixture()));
    await tester.tap(find.text('Linear equations'));
    await tester.pumpAndSettle();
    expect(find.text('topic:t1'), findsOneWidget);
  });

  testWidgets('L-1: tapping an open row goes to its topic', (tester) async {
    await _pump(tester, CourseMapLoaded(courseMapFixture()));
    await tester.tap(find.text('Systems'));
    await tester.pumpAndSettle();
    expect(find.text('topic:t2'), findsOneWidget);
  });

  testWidgets('L-1: continue card shows copy and navigates', (tester) async {
    await _pump(
      tester,
      CourseMapLoaded(courseMapFixture(continueTopic: continueMapTopic)),
    );
    expect(find.text('Continue where you left off'), findsOneWidget);
    expect(find.text('Systems · Algebra'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('topic:t2'), findsOneWidget);
  });

  testWidgets('L-1: continue card is hidden when there is no continue topic', (
    tester,
  ) async {
    await _pump(tester, CourseMapLoaded(courseMapFixture()));
    expect(find.text('Continue where you left off'), findsNothing);
  });

  testWidgets('L-1: a course with no units shows the empty state', (
    tester,
  ) async {
    await _pump(tester, CourseMapLoaded(courseMapFixture(units: const [])));
    expect(find.text('This course has no topics yet.'), findsOneWidget);
  });

  final failures = <(String, String, String, String)>[
    (
      ErrorCodes.notEnrolled,
      'No course yet',
      "You're not enrolled in a course yet.",
      '',
    ),
    (
      ErrorCodes.accessExpired,
      'Access ended',
      'Your access has ended. Contact your teacher.',
      '',
    ),
    (
      ErrorCodes.network,
      "Couldn't load your course",
      'Check your connection and try again.',
      'Retry',
    ),
    (
      ErrorCodes.internal,
      "Couldn't load your course",
      'Something went wrong. Try again.',
      'Retry',
    ),
  ];
  for (final (code, title, body, retry) in failures) {
    testWidgets('L-1: $code failure shows its copy', (tester) async {
      await _pump(tester, CourseMapFailed(AppError(code)));
      expect(find.text(title), findsOneWidget);
      expect(find.text(body), findsOneWidget);
      expect(find.text('Retry'), retry.isEmpty ? findsNothing : findsOneWidget);
    });
  }

  testWidgets('L-1: Retry calls the cubit retry', (tester) async {
    final cubit = courseMapCubit(
      const CourseMapFailed(AppError(ErrorCodes.network)),
    );
    await _pump(tester, cubit.state, cubit: cubit);
    await tester.tap(find.text('Retry'));
    await tester.pump();
    verify(cubit.retry).called(1);
  });

  testWidgets('S-10: unenrolled student can enter an activation code', (
    tester,
  ) async {
    await _pump(
      tester,
      const CourseMapFailed(AppError(ErrorCodes.notEnrolled)),
    );

    await tester.tap(find.text('Enter activation code'));
    await tester.pumpAndSettle();

    expect(find.text('activation form'), findsOneWidget);
  });

  for (final code in [ErrorCodes.accessExpired, ErrorCodes.network]) {
    testWidgets('S-10: $code has no activation action', (tester) async {
      await _pump(tester, CourseMapFailed(AppError(code)));

      expect(find.text('Enter activation code'), findsNothing);
    });
  }
}
