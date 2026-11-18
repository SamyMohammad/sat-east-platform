import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/core/router/app_router.dart';
import 'package:sat_east_client/core/theme/app_theme.dart';
import 'package:sat_east_client/features/mock/domain/entities/mock_entities.dart';
import 'package:sat_east_client/features/mock/presentation/cubit/mock_hub_cubit.dart';
import 'package:sat_east_client/features/mock/presentation/mock_copy.dart';
import 'package:sat_east_client/features/mock/presentation/screens/mock_pre_exam_screen.dart';
import 'package:sat_east_client/shared/widgets/app_banner.dart';

import '../mock_fakes.dart';

Future<MockHubCubit> _pump(
  WidgetTester tester,
  FakeMockRepository repo, {
  double width = 1280,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 1000);
  addTearDown(tester.view.reset);
  final cubit = MockHubCubit(repo);
  addTearDown(cubit.close);
  await cubit.load();
  final router = GoRouter(
    initialLocation: AppRoutes.mockStart,
    routes: [
      GoRoute(
        path: AppRoutes.mockExams,
        builder: (_, _) => const Text('Hub page'),
      ),
      GoRoute(
        path: AppRoutes.mockStart,
        builder: (_, _) => Scaffold(
          body: BlocProvider.value(
            value: cubit,
            child: const MockPreExamView(),
          ),
        ),
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
  return cubit;
}

void main() {
  testWidgets('MCK-01: shows the rules and the start button', (tester) async {
    await _pump(tester, FakeMockRepository());
    expect(find.text(MockCopy.preExamTitle), findsOneWidget);
    for (final rule in MockCopy.preExamRules) {
      expect(find.text(rule), findsOneWidget);
    }
    expect(find.text(MockCopy.startModule1), findsOneWidget);
    // The break length comes from a setting and is not promised in copy.
    expect(find.textContaining('minute break'), findsNothing);
  });

  testWidgets('MCK-01: the phone banner shows at 360 and not at 1280', (
    tester,
  ) async {
    await _pump(tester, FakeMockRepository(), width: 360);
    expect(find.text(MockCopy.phoneBanner), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('MCK-01: no phone banner on a wide screen', (tester) async {
    await _pump(tester, FakeMockRepository());
    expect(find.text(MockCopy.phoneBanner), findsNothing);
  });

  testWidgets('MCK-01: Start module 1 calls start_mock and opens the exam', (
    tester,
  ) async {
    final repo = FakeMockRepository()
      ..startResult = Success(
        MockGapStage(
          groupId: 'g-9',
          gapUntil: DateTime.utc(2026),
          serverNow: DateTime.utc(2026),
        ),
      );
    await _pump(tester, repo);
    await tester.tap(find.text(MockCopy.startModule1));
    await tester.pumpAndSettle();
    expect(repo.startCalls, [fakeCourseId]);
    expect(find.text('Run page g-9'), findsOneWidget);
  });

  testWidgets('MCK-01: a double tap starts once', (tester) async {
    final repo = FakeMockRepository();
    final gate = repo.startGate = Completer<void>();
    await _pump(tester, repo);
    await tester.tap(find.text(MockCopy.startModule1));
    await tester.pump();
    await tester.tap(find.byType(FilledButton), warnIfMissed: false);
    await tester.pump();
    gate.complete();
    await tester.pumpAndSettle();
    expect(repo.startCalls, hasLength(1));
  });

  for (final code in [
    ErrorCodes.mockLocked,
    ErrorCodes.mockNoneAvailable,
    ErrorCodes.accessExpired,
    ErrorCodes.notEnrolled,
    ErrorCodes.rateLimited,
    ErrorCodes.internal,
  ]) {
    testWidgets('MCK-01: start error $code shows its copy and stays', (
      tester,
    ) async {
      final repo = FakeMockRepository()..startResult = Failure(AppError(code));
      await _pump(tester, repo);
      await tester.tap(find.text(MockCopy.startModule1));
      await tester.pumpAndSettle();
      expect(find.byType(AppBanner), findsWidgets);
      expect(find.text(MockCopy.errorBody(code)), findsOneWidget);
      expect(find.text(MockCopy.startModule1), findsOneWidget);
    });
  }

  testWidgets('MCK-01: no SAT course shows the enrolment empty state', (
    tester,
  ) async {
    final repo = FakeMockRepository()..course = const Success(null);
    await _pump(tester, repo);
    expect(find.text(MockCopy.noCourseTitle), findsOneWidget);
    expect(find.text(MockCopy.startModule1), findsNothing);
  });

  testWidgets('MCK-01: a load failure on the pre-exam page can retry', (
    tester,
  ) async {
    final repo = FakeMockRepository()
      ..hubResult = const Failure(AppError(ErrorCodes.network));
    await _pump(tester, repo);
    expect(find.text(MockCopy.retry), findsOneWidget);
    repo.hubResult = const Success(fakeHub);
    await tester.tap(find.text(MockCopy.retry));
    await tester.pumpAndSettle();
    expect(find.text(MockCopy.startModule1), findsOneWidget);
  });
}
