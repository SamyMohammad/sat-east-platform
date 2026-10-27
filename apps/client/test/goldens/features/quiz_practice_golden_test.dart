@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/features/practice/presentation/widgets/practice_summary.dart';
import 'package:sat_east_client/features/quiz/presentation/screens/quiz_result_screen.dart';

import '../../features/quiz/presentation/quiz_result_redesign_test.dart'
    show failedReport, passedReport;
import 'feature_golden_harness.dart';

void main() {
  for (final width in [360.0, 1280.0]) {
    for (final brightness in Brightness.values) {
      for (final state in ['pass', 'fail', 'practice_summary']) {
        final name =
            'quiz_practice_${state}_${brightness.name}_${width.toInt()}';
        testWidgets('PRC-03: golden $name', (tester) async {
          await expectFeatureGolden(
            tester,
            name: name,
            width: width,
            brightness: brightness,
            location: '/result',
            child: Scaffold(
              body: state == 'practice_summary'
                  ? SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: PracticeSummaryView(
                        correctFirstTry: 2,
                        total: 3,
                        onPracticeMore: () {},
                        onBack: () {},
                        onBackToTopic: () {},
                      ),
                    )
                  : QuizResultScreen(
                      topicId: 't1',
                      report: state == 'pass' ? passedReport : failedReport,
                    ),
            ),
          );
          if (state == 'practice_summary') {
            expect(find.text('2 / 3'), findsOneWidget);
            expect(
              find.text('You got 2 of 3 right on the first try.'),
              findsOneWidget,
            );
            final primary = tester.getRect(find.byType(FilledButton));
            final topic = tester.getRect(find.byType(OutlinedButton).first);
            final course = tester.getRect(find.byType(OutlinedButton).last);
            expect(topic.width, course.width);
            if (width < 600) {
              expect(topic.width, primary.width);
              expect(course.top, greaterThan(topic.bottom));
            } else {
              expect(topic.top, course.top);
              expect(topic.left, primary.left);
              expect(course.right, primary.right);
            }
          }
        });
      }
    }
  }
}
