import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/theme/app_theme.dart';
import 'package:sat_east_client/core/theme/app_type.dart';
import 'package:sat_east_client/features/practice/presentation/widgets/practice_summary.dart';
import 'package:sat_east_client/shared/widgets/app_illustration.dart';

void main() {
  testWidgets('practice_summary_shows_illustration_and_stats', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: PracticeSummaryView(
              correctFirstTry: 2,
              total: 3,
              onPracticeMore: () {},
              onBack: () {},
              onBackToTopic: () {},
            ),
          ),
        ),
      ),
    );
    expect(
      tester.widget<AppIllustration>(find.byType(AppIllustration)).name,
      AppIllustrationName.practiceDone,
    );
    expect(find.text('2 / 3'), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('2 / 3')).style?.fontFeatures,
      AppType.count.fontFeatures,
    );
    expect(find.text('right on the first try.'), findsNothing);
    expect(find.text('Practice'), findsNothing);
    expect(find.text('You got 2 of 3 right on the first try.'), findsOneWidget);
  });
  for (final width in [360.0, 599.0, 600.0, 1280.0]) {
    testWidgets('practice summary actions fit $width', (tester) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final calls = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: PracticeSummaryView(
                correctFirstTry: 2,
                total: 3,
                onPracticeMore: () => calls.add('more'),
                onBack: () => calls.add('course'),
                onBackToTopic: () => calls.add('topic'),
              ),
            ),
          ),
        ),
      );
      final primary = tester.getRect(find.byType(FilledButton));
      final topic = tester.getRect(find.byType(OutlinedButton).first);
      final course = tester.getRect(find.byType(OutlinedButton).last);
      expect(primary.width, lessThanOrEqualTo(560));
      expect(topic.width, course.width);
      expect(topic.top, greaterThan(primary.bottom));
      if (width < 600) {
        expect(topic.width, primary.width);
        expect(course.width, primary.width);
        expect(course.top, greaterThan(topic.bottom));
      } else {
        expect(topic.top, course.top);
        expect(topic.left, primary.left);
        expect(course.right, primary.right);
        expect(course.left, greaterThan(topic.right));
      }
      for (final label in [
        'Practice more',
        'Back to topic',
        'Back to course',
      ]) {
        await tester.ensureVisible(find.text(label));
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
      }
      expect(calls, ['more', 'topic', 'course']);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('practice summary fits 360 at 2x text', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            child: PracticeSummaryView(
              correctFirstTry: 2,
              total: 3,
              onPracticeMore: () {},
              onBack: () {},
              onBackToTopic: () {},
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Back to course'));
    expect(find.text('Back to course').hitTestable(), findsOneWidget);
  });
}
