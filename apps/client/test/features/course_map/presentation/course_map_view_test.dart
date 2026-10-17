import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/core/theme/app_theme.dart';
import 'package:sat_east_client/features/course_map/domain/entities/course_map.dart';
import 'package:sat_east_client/features/course_map/presentation/cubit/course_map_cubit.dart';
import 'package:sat_east_client/features/course_map/presentation/cubit/course_map_state.dart';
import 'package:sat_east_client/features/course_map/presentation/screens/course_map_screen.dart';
import 'package:sat_east_client/shared/widgets/booklet_skeleton.dart';

class _MockCubit extends MockCubit<CourseMapState> implements CourseMapCubit {}

const _done = MapTopic(
  id: 't1',
  slug: 'linear',
  title: 'Linear equations',
  sortLabel: '1.1',
  isFreePreview: true,
  status: TopicStatus.completed,
  lockReason: null,
);
const _open = MapTopic(
  id: 't2',
  slug: 'systems',
  title: 'Systems',
  sortLabel: '1.2',
  isFreePreview: false,
  status: TopicStatus.open,
  lockReason: null,
);
const _locked = MapTopic(
  id: 't3',
  slug: 'quadratics',
  title: 'Quadratics',
  sortLabel: '2.1',
  isFreePreview: false,
  status: TopicStatus.locked,
  lockReason: PreviousQuiz('Systems'),
);

CourseMap _map({ContinueTopic? continueTopic, List<MapUnit>? units}) =>
    CourseMap(
      courseId: 'c1',
      slug: 'sat-math',
      title: 'SAT Math',
      continueTopic: continueTopic,
      units:
          units ??
          const [
            MapUnit(title: 'Algebra', topics: [_done, _open]),
            MapUnit(title: null, topics: [_locked]),
          ],
    );

const _continue = ContinueTopic(
  topicId: 't2',
  slug: 'systems',
  title: 'Systems',
  unitTitle: 'Algebra',
);

_MockCubit _cubit(CourseMapState state) {
  final cubit = _MockCubit();
  whenListen(cubit, const Stream<CourseMapState>.empty(), initialState: state);
  when(cubit.retry).thenAnswer((_) async {});
  return cubit;
}

Future<void> _pump(
  WidgetTester tester,
  CourseMapState state, {
  Size size = const Size(360, 800),
  _MockCubit? cubit,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final c = cubit ?? _cubit(state);
  final router = GoRouter(
    initialLocation: '/courses',
    routes: [
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
    MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  for (final (name, size) in [
    ('360x800', const Size(360, 800)),
    ('1280x800', const Size(1280, 800)),
  ]) {
    testWidgets('L-1: loaded map renders without overflow at $name', (
      tester,
    ) async {
      await _pump(
        tester,
        CourseMapLoaded(_map(continueTopic: _continue)),
        size: size,
      );
      expect(find.text('SAT Math'), findsOneWidget);
      expect(find.text('Algebra'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('L-1: loading shows the skeleton', (tester) async {
    await _pump(tester, const CourseMapLoading());
    expect(find.byType(BookletSkeleton), findsOneWidget);
  });

  testWidgets('L-1: rows expose status in their semantics label', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, CourseMapLoaded(_map()));
    expect(find.bySemanticsLabel('1.1 Linear equations, completed'), findsOne);
    expect(find.bySemanticsLabel('1.2 Systems, open'), findsOne);
    expect(find.bySemanticsLabel('2.1 Quadratics, locked'), findsOne);
    handle.dispose();
  });

  testWidgets('L-1: row states show check, lock, free chip and lock line', (
    tester,
  ) async {
    await _pump(tester, CourseMapLoaded(_map()));
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsNWidgets(2));
    expect(find.text('Free'), findsOneWidget);
    expect(find.text('Pass the Systems quiz to unlock'), findsOneWidget);
  });

  testWidgets('L-1: units without a title render no header', (tester) async {
    await _pump(
      tester,
      CourseMapLoaded(
        _map(
          units: const [
            MapUnit(title: null, topics: [_open]),
          ],
        ),
      ),
    );
    expect(find.text('Systems'), findsOneWidget);
    expect(find.text('Algebra'), findsNothing);
  });

  testWidgets('L-1: tapping a locked row does not navigate', (tester) async {
    await _pump(tester, CourseMapLoaded(_map()));
    await tester.tap(find.text('Quadratics'));
    await tester.pumpAndSettle();
    expect(find.text('topic:t3'), findsNothing);
    expect(find.text('SAT Math'), findsOneWidget);
  });

  testWidgets('L-1: tapping an open row goes to its topic', (tester) async {
    await _pump(tester, CourseMapLoaded(_map()));
    await tester.tap(find.text('Systems'));
    await tester.pumpAndSettle();
    expect(find.text('topic:t2'), findsOneWidget);
  });

  testWidgets('L-1: continue card shows copy and navigates', (tester) async {
    await _pump(tester, CourseMapLoaded(_map(continueTopic: _continue)));
    expect(find.text('Continue where you left off'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('topic:t2'), findsOneWidget);
  });

  testWidgets('L-1: continue card is hidden when there is no continue topic', (
    tester,
  ) async {
    await _pump(tester, CourseMapLoaded(_map()));
    expect(find.text('Continue where you left off'), findsNothing);
  });

  testWidgets('L-1: a course with no units shows the empty state', (
    tester,
  ) async {
    await _pump(tester, CourseMapLoaded(_map(units: const [])));
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
      expect(
        find.text('Retry'),
        retry.isEmpty ? findsNothing : findsOneWidget,
      );
    });
  }

  testWidgets('L-1: Retry calls the cubit retry', (tester) async {
    final cubit = _cubit(const CourseMapFailed(AppError(ErrorCodes.network)));
    await _pump(tester, cubit.state, cubit: cubit);
    await tester.tap(find.text('Retry'));
    await tester.pump();
    verify(cubit.retry).called(1);
  });
}
