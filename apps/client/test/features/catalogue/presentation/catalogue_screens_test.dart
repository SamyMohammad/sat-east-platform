import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/core/theme/app_theme.dart';
import 'package:sat_east_client/features/auth/domain/entities/app_user.dart';
import 'package:sat_east_client/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:sat_east_client/features/auth/presentation/cubit/auth_state.dart';
import 'package:sat_east_client/features/catalogue/data/models/catalogue_course_model.dart';
import 'package:sat_east_client/features/catalogue/data/models/course_page_model.dart';
import 'package:sat_east_client/features/catalogue/presentation/cubit/catalogue_cubit.dart';
import 'package:sat_east_client/features/catalogue/presentation/cubit/course_page_cubit.dart';
import 'package:sat_east_client/features/catalogue/presentation/screens/catalogue_screen.dart';
import 'package:sat_east_client/features/catalogue/presentation/screens/course_page_screen.dart';
import 'package:sat_east_client/shared/widgets/app_skeleton.dart';

import '../../auth/presentation/screens/auth_screen_harness.dart' as auth;
import '../catalogue_fixtures.dart';

Future<GoRouter> _pump(
  WidgetTester tester,
  FakeCatalogueRepository repository, {
  bool page = false,
  bool purchase = false,
  AuthState state = const AuthSignedOut(),
  double width = 360,
  double scale = 1,
  bool load = true,
}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final catalogue = CatalogueCubit(repository);
  final course = CoursePageCubit(repository);
  addTearDown(catalogue.close);
  addTearDown(course.close);
  if (load) {
    if (page) {
      await course.load('sat-math');
    } else {
      await catalogue.load();
    }
  }
  final router = GoRouter(
    initialLocation: page ? '/catalogue/sat-math' : '/catalogue',
    routes: [
      GoRoute(
        path: '/catalogue',
        builder: (_, _) => page
            ? const Scaffold(body: Text('browse destination'))
            : CatalogueView(enablePurchase: purchase),
      ),
      GoRoute(
        path: '/catalogue/:slug',
        builder: (_, _) => page
            ? CoursePageView(enablePurchase: purchase)
            : const Scaffold(body: Text('syllabus destination')),
      ),
      for (final path in ['/activate', '/sign-up'])
        GoRoute(
          path: path,
          builder: (_, _) => Scaffold(body: Text('destination:$path')),
        ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MultiBlocProvider(
      providers: [
        BlocProvider<AuthCubit>.value(value: auth.mockCubit(state)),
        BlocProvider<CatalogueCubit>.value(value: catalogue),
        BlocProvider<CoursePageCubit>.value(value: course),
      ],
      child: MaterialApp.router(
        theme: AppTheme.light(),
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

FakeCatalogueRepository _repository({bool price = true}) =>
    FakeCatalogueRepository()
      ..catalogue = Success([
        catalogueCourseFromJson({
          ...coursePayload,
          if (!price) 'price': null,
        }),
      ])
      ..page = Success(
        coursePageFromJson({
          ...pagePayload,
          if (!price) 'price': null,
        }),
      );

void main() {
  for (final page in [false, true]) {
    testWidgets('PAY-01: $page loading shows skeleton', (tester) async {
      await _pump(tester, _repository(), page: page, load: false);
      expect(find.byType(AppSkeleton), findsOneWidget);
    });
    for (final code in ['network', 'internal']) {
      testWidgets('PAY-01: $page $code is safe and retry reloads', (
        tester,
      ) async {
        final repo = _repository()
          ..catalogue = Failure(AppError(code, 'private details'))
          ..page = Failure(AppError(code, 'private details'));
        await _pump(tester, repo, page: page);
        expect(find.textContaining('private details'), findsNothing);
        expect(
          find.text(
            code == 'network'
                ? 'Check your connection and try again.'
                : 'Something went wrong. Try again.',
          ),
          findsOneWidget,
        );
        repo
          ..catalogue = _repository().catalogue
          ..page = _repository().page;
        await tester.tap(find.text('Retry'));
        await tester.pumpAndSettle();
        expect(find.text('SAT Math'), findsOneWidget);
        expect(page ? repo.slugs.length : repo.catalogueCalls, 2);
      });
    }
    for (final width in [360.0, 1280.0]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('PAY-01: $page fits $width at $scale text', (tester) async {
          await _pump(
            tester,
            _repository(),
            page: page,
            width: width,
            scale: scale,
            purchase: true,
          );
          expect(find.text('SAT Math'), findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      }
    }
    for (final purchase in [false, true]) {
      testWidgets('PAY-01: $page price gated by $purchase', (tester) async {
        await _pump(tester, _repository(), page: page, purchase: purchase);
        final price = find.text('EGP 2,400');
        if (purchase) await tester.ensureVisible(price);
        expect(price, purchase ? findsOneWidget : findsNothing);
        expect(find.textContaining('Buy'), findsNothing);
        if (page && !purchase) {
          expect(
            find.text('Sign in or enter an activation code.'),
            findsOneWidget,
          );
        }
      });
    }
    testWidgets('PAY-01: $page null price hides price row', (tester) async {
      await _pump(
        tester,
        _repository(price: false),
        page: page,
        purchase: true,
      );
      expect(find.textContaining('EGP'), findsNothing);
      expect(find.textContaining('USD'), findsNothing);
    });
    testWidgets('PAY-01: $page Arabic content uses direction helper', (
      tester,
    ) async {
      const title = 'الجبر';
      final repo = _repository()
        ..catalogue = Success([
          catalogueCourseFromJson({
            ...coursePayload,
            'title': title,
            'description': title,
          }),
        ])
        ..page = Success(
          coursePageFromJson({
            ...pagePayload,
            'title': title,
            'description': title,
          }),
        );
      await _pump(tester, repo, page: page);
      for (final text in tester.widgetList<Text>(find.text(title))) {
        expect(text.textDirection, TextDirection.rtl);
      }
    });
  }
  testWidgets('PAY-01: catalogue empty state is explicit', (tester) async {
    await _pump(tester, FakeCatalogueRepository());
    expect(find.text('No courses yet'), findsOneWidget);
    expect(
      find.text("Courses will appear here once they're published."),
      findsOneWidget,
    );
  });
  testWidgets('PAY-01: catalogue card opens the syllabus slug', (tester) async {
    final router = await _pump(tester, _repository());
    expect(find.text('3 topics'), findsOneWidget);
    expect(find.text('Build your math skills.'), findsOneWidget);
    await tester.tap(find.text('See the syllabus'));
    await tester.pumpAndSettle();
    expect(
      router.routerDelegate.currentConfiguration.last.matchedLocation,
      '/catalogue/sat-math',
    );
  });
  testWidgets('PAY-01: syllabus numbers reset per unit with free badge', (
    tester,
  ) async {
    await _pump(tester, _repository(), page: true);
    for (final text in [
      'Algebra',
      'Advanced math',
      'Linear equations',
      'Systems',
      'Quadratics',
      '1.1',
      '1.2',
      '2.1',
      '4 subtopics',
      'Free',
    ]) {
      expect(find.text(text), findsOneWidget);
    }
    expect(find.text('Try free'), findsNothing);
  });
  testWidgets('PAY-01: page with no units keeps header and activation CTA', (
    tester,
  ) async {
    final repo = _repository()
      ..page = Success(
        coursePageFromJson({
          ...pagePayload,
          'units': <Object?>[],
        }),
      );
    await _pump(tester, repo, page: true);
    expect(find.text('SAT Math'), findsOneWidget);
    expect(find.text('Have an activation code?'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  for (final signedIn in [false, true]) {
    testWidgets('PAY-01: activation CTA targets auth state $signedIn', (
      tester,
    ) async {
      final router = await _pump(
        tester,
        _repository(),
        page: true,
        state: signedIn
            ? const AuthSignedIn(AppUser(id: 'u1', email: 'a@b.co'))
            : const AuthSignedOut(),
      );
      final cta = find.text('Have an activation code?');
      await tester.ensureVisible(cta);
      await tester.tap(cta);
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.path,
        signedIn ? '/activate' : '/sign-up',
      );
    });
  }
  testWidgets('PAY-01: invalid_input shows course not found and browse', (
    tester,
  ) async {
    final repo = _repository()
      ..page = const Failure(AppError('invalid_input', 'private details'));
    final router = await _pump(tester, repo, page: true);
    expect(find.text('Course not found'), findsOneWidget);
    expect(find.text("This course isn't available."), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
    await tester.tap(find.text('Browse courses'));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/catalogue');
  });
}
