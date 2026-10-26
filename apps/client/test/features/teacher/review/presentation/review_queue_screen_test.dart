import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/core/theme/app_theme.dart';
import 'package:sat_east_client/features/teacher/review/domain/entities/review.dart';
import 'package:sat_east_client/features/teacher/review/presentation/screens/review_queue_screen.dart';
import 'package:sat_east_client/features/teacher/shell/teacher_shell.dart';

import '../review_fixtures.dart';

void main() {
  for (final (count, label) in [(1, '1 question'), (2, '2 questions')]) {
    testWidgets('T-08: queue count pluralizes $count', (tester) async {
      final repo = FakeReviewRepository()
        ..pending = Future.value(Success(reviewPage(total: count)));
      registerReviewFakes(repository: repo);
      addTearDown(unregisterReviewFakes);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: ReviewQueueScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(label), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  for (final width in [360.0, 1280.0]) {
    testWidgets('T-08: tabs, paging, row navigation and layout at $width', (
      tester,
    ) async {
      final repo = FakeReviewRepository();
      registerReviewFakes(repository: repo);
      addTearDown(unregisterReviewFakes);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 900);
      addTearDown(tester.view.reset);
      final router = GoRouter(
        initialLocation: '/teacher/review',
        routes: [
          GoRoute(
            path: '/teacher/review',
            builder: (_, _) => const TeacherShell(child: ReviewQueueScreen()),
          ),
          GoRoute(
            path: '/teacher/questions/:id',
            builder: (_, s) =>
                Scaffold(body: Text('Editor ${s.pathParameters['id']}')),
          ),
        ],
      );
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        router.dispose();
      });
      await tester.pumpWidget(
        MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
      );
      await tester.pumpAndSettle();
      expect(find.text('Review queue'), findsOneWidget);
      expect(find.text('<b>plain note</b>'), findsOneWidget);
      expect(find.text('Answer key is wrong (1)'), findsOneWidget);
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(repo.pages.last, (ReviewSection.reported, 2));
      await tester.tap(find.text('Previous'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Needs review'));
      await tester.pumpAndSettle();
      expect(repo.pages.last, (ReviewSection.needsReview, 1));
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('REF_1'));
      await tester.pumpAndSettle();
      expect(find.text('Editor q1'), findsOneWidget);
    });
  }
  testWidgets('T-08: queue failure offers retry', (tester) async {
    final repo = FakeReviewRepository()
      ..listError = const AppError('forbidden');
    registerReviewFakes(repository: repo);
    addTearDown(unregisterReviewFakes);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const TeacherShell(child: ReviewQueueScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Only the teacher can view the review queue.'),
      findsOneWidget,
    );
    repo.listError = null;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('REF_1'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
