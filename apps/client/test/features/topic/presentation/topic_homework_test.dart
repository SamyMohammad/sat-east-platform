import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/theme/app_theme.dart';
import 'package:sat_east_client/features/topic/domain/entities/topic_detail.dart';
import 'package:sat_east_client/features/topic/domain/entities/topic_homework.dart';
import 'package:sat_east_client/features/topic/presentation/widgets/topic_content.dart';

void main() {
  for (final width in [360.0, 1280.0]) {
    for (final state in HomeworkState.values) {
      testWidgets('PRC-02: topic homework ${state.name} at $width', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 1600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        var opened = 0;
        var reviewed = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: SingleChildScrollView(
                child: TopicContent(
                  topic: TopicDetail(
                    id: 't1',
                    title: 'Topic',
                    sortLabel: '1',
                    status: TopicStatus.open,
                    practiceCount: 10,
                    practiceMin: 10,
                    quiz: const QuizHomeworkNeeded(),
                    homework: TopicHomework(
                      state: state,
                      attemptId: 'hw1',
                      scorePct: 8.33,
                      total: 20,
                      answered: 8,
                    ),
                  ),
                  onPractice: () {},
                  onQuiz: () {},
                  onHomework: () => opened++,
                  onReport: (_) => reviewed++,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Submit the homework first.'), findsOneWidget);
        switch (state) {
          case HomeworkState.available:
            await tester.tap(find.text('Start homework'));
            expect(opened, 1);
          case HomeworkState.inProgress:
            await tester.tap(find.text('Continue homework (8 / 20 answered)'));
            expect(opened, 1);
          case HomeworkState.submitted:
            expect(find.text('Submitted \u00b7 8%'), findsOneWidget);
            await tester.tap(find.text('View report'));
            expect(reviewed, 1);
          case HomeworkState.skipped:
            expect(find.text('Homework'), findsNothing);
          case HomeworkState.lockedByPractice:
            expect(find.text('Start homework'), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      });
    }
  }
}
