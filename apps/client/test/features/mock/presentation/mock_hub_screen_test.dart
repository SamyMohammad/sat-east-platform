import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/core/router/app_router.dart';
import 'package:sat_east_client/core/theme/app_theme.dart';
import 'package:sat_east_client/features/mock/presentation/cubit/mock_hub_cubit.dart';
import 'package:sat_east_client/features/mock/presentation/mock_copy.dart';
import 'package:sat_east_client/features/mock/presentation/screens/mock_hub_screen.dart';

import '../mock_fakes.dart';

Future<(MockHubCubit, GoRouter)> _pump(
  WidgetTester tester,
  FakeMockRepository repo, {
  double width = 1280,
  bool load = true,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 1000);
  addTearDown(tester.view.reset);
  final cubit = MockHubCubit(repo);
  addTearDown(cubit.close);
  if (load) await cubit.load();
  final router = GoRouter(
    initialLocation: AppRoutes.mockExams,
    routes: [
      GoRoute(
        path: AppRoutes.mockExams,
        builder: (_, _) => Scaffold(
          body: BlocProvider.value(value: cubit, child: const MockHubView()),
        ),
      ),
      GoRoute(
        path: AppRoutes.mockStart,
        builder: (_, _) => const Text('Pre-exam page'),
      ),
      GoRoute(
        path: '/mock-exams/run/:groupId',
        builder: (_, state) =>
            Text('Run page ${state.pathParameters['groupId']}'),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
  );
  await tester.pumpAndSettle();
  return (cubit, router);
}

void main() {
  testWidgets('MCK-01: the four form states render their own card', (
    tester,
  ) async {
    final repo = FakeMockRepository()
      ..hubResult = const Success(
        MockHubFixtures.allStates,
      );
    await _pump(tester, repo);
    expect(find.text(MockCopy.hubTitle), findsOneWidget);
    expect(find.text('Mock exam 1'), findsOneWidget);
    expect(find.text(MockCopy.finished), findsOneWidget);
    expect(find.text(MockCopy.inProgress), findsOneWidget);
    expect(find.text(MockCopy.available), findsOneWidget);
    expect(find.text(MockCopy.unlockHint(12, 7)), findsOneWidget);
    expect(find.text(MockCopy.resume), findsOneWidget);
    // An unfinished run is resumed before anything new can start.
    expect(find.text(MockCopy.start), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('MCK-01: Start opens the pre-exam page', (tester) async {
    await _pump(tester, FakeMockRepository());
    await tester.tap(find.text(MockCopy.start));
    await tester.pumpAndSettle();
    expect(find.text('Pre-exam page'), findsOneWidget);
  });

  testWidgets('MCK-01: Resume opens the exam of active_group', (tester) async {
    final repo = FakeMockRepository()..hubResult = const Success(fakeResumeHub);
    await _pump(tester, repo);
    expect(find.text(MockCopy.start), findsNothing);
    await tester.tap(find.text(MockCopy.resume));
    await tester.pumpAndSettle();
    expect(find.text('Run page $fakeGroupId'), findsOneWidget);
  });

  testWidgets('MCK-01: a locked form shows the unlock hint and no button', (
    tester,
  ) async {
    await _pump(tester, FakeMockRepository());
    expect(find.text(MockCopy.unlockHint(12, 7)), findsOneWidget);
    expect(find.text(MockCopy.locked), findsOneWidget);
  });

  testWidgets('MCK-01: no SAT course shows the enrolment empty state', (
    tester,
  ) async {
    final repo = FakeMockRepository()..course = const Success(null);
    await _pump(tester, repo);
    expect(find.text(MockCopy.noCourseTitle), findsOneWidget);
    expect(repo.hubCalls, isEmpty);
  });

  testWidgets('MCK-01: a load failure shows retry and recovers', (
    tester,
  ) async {
    final repo = FakeMockRepository()
      ..hubResult = const Failure(AppError(ErrorCodes.network));
    await _pump(tester, repo);
    expect(find.text(MockCopy.errorTitle(ErrorCodes.network)), findsOneWidget);
    repo.hubResult = const Success(fakeHub);
    await tester.tap(find.text(MockCopy.retry));
    await tester.pumpAndSettle();
    expect(find.text('Mock exam 1'), findsOneWidget);
  });

  testWidgets('MCK-01: a hub with no forms says so', (tester) async {
    final repo = FakeMockRepository()
      ..hubResult = const Success(
        MockHubFixtures.empty,
      );
    await _pump(tester, repo);
    expect(find.text(MockCopy.noFormsTitle), findsOneWidget);
  });

  testWidgets('MCK-01: the hub fits 360 px without overflow', (tester) async {
    final repo = FakeMockRepository()
      ..hubResult = const Success(
        MockHubFixtures.allStates,
      );
    await _pump(tester, repo, width: 360);
    expect(tester.takeException(), isNull);
    expect(find.text(MockCopy.resume), findsOneWidget);
  });
}
