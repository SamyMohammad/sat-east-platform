import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/theme/app_theme.dart';
import 'package:sat_east_client/features/practice/presentation/practice_copy.dart';
import 'package:sat_east_client/shared/widgets/report_problem_sheet.dart';

void main() {
  for (final width in [360.0, 599.0, 600.0, 1280.0]) {
    testWidgets('QB-04: report form uses the correct overlay at $width', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 900);
      addTearDown(tester.view.reset);
      ({String reason, String? note})? result;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  result = await showReportProblemSheet(
                    context,
                    reasons: PracticeCopy.reportReasons,
                  );
                },
                child: const Text('Open report'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open report'));
      await tester.pumpAndSettle();
      expect(
        find.byType(BottomSheet),
        width < 600 ? findsOneWidget : findsNothing,
      );
      expect(find.byType(Dialog), width >= 600 ? findsOneWidget : findsNothing);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Submit'))
            .onPressed,
        isNull,
      );
      await tester.tap(find.text('The answer key is wrong'));
      await tester.enterText(find.byType(TextFormField), '  My note  ');
      await tester.ensureVisible(find.text('Submit'));
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();
      expect(result, (reason: 'answer_key', note: 'My note'));
      expect(tester.takeException(), isNull);
    });
  }
  for (final entry in PracticeCopy.reportReasons.entries) {
    testWidgets('QB-04: ${entry.key} and optional blank note returned', (
      tester,
    ) async {
      ({String reason, String? note})? result;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  result = await showReportProblemSheet(
                    context,
                    reasons: PracticeCopy.reportReasons,
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(entry.value));
      await tester.enterText(find.byType(TextFormField), '   ');
      await tester.ensureVisible(find.text('Submit'));
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();
      expect(result, (reason: entry.key, note: null));
    });
  }
  testWidgets('QB-04: note limit rejects 501 and accepts 500; counter shown', (
    tester,
  ) async {
    ({String reason, String? note})? result;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showReportProblemSheet(
                  context,
                  reasons: PracticeCopy.reportReasons,
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Other'));
    await tester.enterText(find.byType(TextFormField), 'x' * 501);
    await tester.ensureVisible(find.text('Submit'));
    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();
    expect(
      find.text('The note must be 500 characters or fewer.'),
      findsOneWidget,
    );
    expect(result, isNull);
    await tester.enterText(find.byType(TextFormField), 'x' * 500);
    await tester.pump();
    expect(find.text('500/500'), findsOneWidget);
    await tester.ensureVisible(find.text('Submit'));
    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();
    expect(result?.note, hasLength(500));
  });
  testWidgets('QB-04: Cancel returns null and reopening starts empty', (
    tester,
  ) async {
    ({String reason, String? note})? result;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showReportProblemSheet(
                  context,
                  reasons: PracticeCopy.reportReasons,
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Other'));
    await tester.enterText(find.byType(TextFormField), 'Unused');
    await tester.ensureVisible(find.text('Cancel'));
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(result, isNull);
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextFormField>(find.byType(TextFormField)).controller?.text,
      isEmpty,
    );
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Submit'))
          .onPressed,
      isNull,
    );
  });
  testWidgets('QB-04: phone form stays usable with keyboard and RTL note', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 800);
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.reset);
    ({String reason, String? note})? result;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showReportProblemSheet(
                  context,
                  reasons: PracticeCopy.reportReasons,
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Other'));
    await tester.tap(find.text('Other'));
    await tester.enterText(
      find.byType(TextFormField),
      '\u0645\u0644\u0627\u062d\u0638\u0629',
    );
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField)).textDirection,
      TextDirection.rtl,
    );
    await tester.ensureVisible(find.text('Submit'));
    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();
    expect(result?.reason, 'other');
    expect(tester.takeException(), isNull);
  });

  testWidgets('QB-04: counter matches SQL characters for combining text', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: ReportProblemSheet(reasons: PracticeCopy.reportReasons),
        ),
      ),
    );
    await tester.enterText(find.byType(TextFormField), 'a\u0301' * 250);
    await tester.pump();
    expect(find.text('500/500'), findsOneWidget);
  });
}
