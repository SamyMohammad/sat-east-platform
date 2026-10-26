import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/core/theme/app_icons.dart';
import 'package:sat_east_client/core/theme/app_theme.dart';
import 'package:sat_east_client/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:sat_east_client/features/auth/presentation/cubit/auth_state.dart';
import 'package:sat_east_client/features/catalogue/data/models/catalogue_course_model.dart';
import 'package:sat_east_client/features/catalogue/data/models/course_page_model.dart';
import 'package:sat_east_client/features/catalogue/presentation/cubit/catalogue_cubit.dart';
import 'package:sat_east_client/features/catalogue/presentation/cubit/course_page_cubit.dart';
import 'package:sat_east_client/features/catalogue/presentation/screens/catalogue_screen.dart';
import 'package:sat_east_client/features/catalogue/presentation/screens/course_page_screen.dart';

import '../../auth/presentation/screens/auth_screen_harness.dart' as auth;
import '../catalogue_fixtures.dart';

Future<GoRouter> _pump(WidgetTester tester, String location) async {
  final repository = FakeCatalogueRepository()
    ..catalogue = Success([catalogueCourseFromJson(coursePayload)])
    ..page = Success(coursePageFromJson(pagePayload));
  final catalogue = CatalogueCubit(repository);
  final course = CoursePageCubit(repository);
  addTearDown(catalogue.close);
  addTearDown(course.close);
  await catalogue.load();
  await course.load('sat-math');
  final router = GoRouter(
    initialLocation: location,
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: Text('home destination')),
      ),
      GoRoute(
        path: '/origin',
        builder: (_, _) => const Scaffold(body: Text('previous destination')),
      ),
      GoRoute(
        path: '/catalogue',
        builder: (_, _) => const CatalogueView(),
      ),
      GoRoute(
        path: '/catalogue/:slug',
        builder: (_, _) => const CoursePageView(),
      ),
    ],
  );
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    router.dispose();
  });
  await tester.pumpWidget(
    MultiBlocProvider(
      providers: [
        BlocProvider<AuthCubit>.value(
          value: auth.mockCubit(const AuthSignedOut()),
        ),
        BlocProvider<CatalogueCubit>.value(value: catalogue),
        BlocProvider<CoursePageCubit>.value(value: course),
      ],
      child: MaterialApp.router(
        theme: AppTheme.light(),
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

void main() {
  for (final (location, fallback) in [
    ('/catalogue', '/'),
    ('/catalogue/sat-math', '/catalogue'),
  ]) {
    testWidgets('PAY-01: cold $location back goes to $fallback', (
      tester,
    ) async {
      final router = await _pump(tester, location);
      expect(router.canPop(), isFalse);
      expect(find.byTooltip('Back'), findsOneWidget);
      expect(find.byIcon(AppIcons.back), findsOneWidget);

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      expect(router.routeInformationProvider.value.uri.path, fallback);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('PAY-01: syllabus pushes page and Back pops to catalogue', (
    tester,
  ) async {
    final router = await _pump(tester, '/catalogue');
    await tester.tap(find.text('See the syllabus'));
    await tester.pumpAndSettle();

    expect(
      router.routerDelegate.currentConfiguration.last.matchedLocation,
      '/catalogue/sat-math',
    );
    expect(find.byType(CoursePageView), findsOneWidget);
    expect(router.canPop(), isTrue);
    expect(find.byType(BackButton), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(find.byType(CatalogueView), findsOneWidget);
    expect(find.text('See the syllabus'), findsOneWidget);
    expect(find.byType(CoursePageView), findsNothing);
    expect(router.canPop(), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('PAY-01: existing history takes precedence over fallback', (
    tester,
  ) async {
    final router = await _pump(tester, '/origin');
    final navigation = router.push<void>('/catalogue');
    await tester.pumpAndSettle();

    expect(find.byType(BackButton), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await navigation;

    expect(find.text('previous destination'), findsOneWidget);
    expect(find.text('home destination'), findsNothing);
    expect(router.canPop(), isFalse);
  });
}
