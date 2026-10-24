import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/core/theme/app_theme.dart';
import 'package:sat_east_client/features/teacher/review/presentation/widgets/review_reports_panel.dart';
import 'package:sat_east_client/features/teacher/shell/teacher_shell.dart';

import '../review_fixtures.dart';

Future<void> pumpPanel(
  WidgetTester tester,
  FakeReviewRepository repo, {
  double width = 1280,
}) async {
  registerReviewFakes(repository: repo);
  addTearDown(unregisterReviewFakes);
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 900);
  addTearDown(tester.view.reset);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
  });
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: const TeacherShell(
        child: SingleChildScrollView(
          child: ReviewReportsPanel(questionId: 'q1'),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final width in [360.0, 1280.0]) {
    for (final action in [
      ('Mark fixed', 'fixed'),
      ('Not a problem', 'dismissed'),
    ]) {
      testWidgets(
        'T-08: resolve-all ${action.$2}, cancel and plain notes at $width',
        (tester) async {
          final repo = FakeReviewRepository()..reportsValue = openReports;
          await pumpPanel(tester, repo, width: width);
          final note = tester.widget<Text>(find.text('<b>Plain report</b>'));
          expect(note.textDirection, isNotNull);
          expect(find.text('Student name'), findsOneWidget);
          final date = MaterialLocalizations.of(
            tester.element(find.text('Reports')),
          ).formatMediumDate(openReports.single.createdAt.toLocal());
          expect(find.text(date), findsOneWidget);
          await tester.tap(find.text(action.$1));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Cancel'));
          await tester.pumpAndSettle();
          expect(repo.resolutions, isEmpty);
          await tester.tap(find.text(action.$1));
          await tester.pumpAndSettle();
          await tester.enterText(
            find.widgetWithText(TextField, 'Optional note'),
            '  Fixed now  ',
          );
          await tester.tap(
            find.descendant(
              of: find.byType(AlertDialog),
              matching: find.widgetWithText(FilledButton, action.$1),
            ),
          );
          await tester.pumpAndSettle();
          expect(repo.resolutions, [('q1', action.$2, 'Fixed now')]);
          expect(find.text('Reports'), findsNothing);
          expect(repo.countCalls, greaterThan(1));
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  testWidgets('T-08: reports empty, read failure/retry and failed resolution', (
    tester,
  ) async {
    final repo = FakeReviewRepository()
      ..reportsError = const AppError('network');
    await pumpPanel(tester, repo);
    expect(find.text('Retry'), findsOneWidget);
    repo
      ..reportsError = null
      ..reportsValue = openReports;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    repo.resolveError = const AppError('invalid_input');
    await tester.tap(find.text('Mark fixed'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'Mark fixed'),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text("That change wasn't saved. Reload and try again."),
      findsOneWidget,
    );
    expect(find.text('<b>Plain report</b>'), findsOneWidget);
    repo
      ..resolveError = null
      ..reportsValue = [];
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Reports'), findsNothing);
  });
}
