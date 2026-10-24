import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/theme/app_theme.dart';
import 'package:sat_east_client/shared/widgets/question_view/answer_state.dart';
import 'package:sat_east_client/shared/widgets/question_view/practice_feedback.dart';
import 'package:sat_east_client/shared/widgets/question_view/question_data.dart';
import 'package:sat_east_client/shared/widgets/question_view/question_view.dart';
import 'package:sat_east_client/shared/widgets/question_view/question_view_mode.dart';

void main() {
  for (final width in [360.0, 1280.0]) {
    testWidgets('QB-04: report callback controls visibility at $width', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 800);
      addTearDown(tester.view.reset);
      var reports = 0;
      Widget app(VoidCallback? onReport) => MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: QuestionView(
            title: 'Practice',
            question: const QuestionData(
              id: 'q1',
              label: 'Question 1',
              stemMd: 'Solve.',
              kind: McqKind([
                ChoiceData(label: 'A', md: 'One'),
                ChoiceData(label: 'B', md: 'Two'),
              ]),
            ),
            mode: const PracticeMode(feedback: Idle(), rep: 1, repTarget: 2),
            answer: const AnswerState(),
            onReport: onReport,
          ),
        ),
      );
      await tester.pumpWidget(app(null));
      await tester.pumpAndSettle();
      expect(find.text('Report a problem'), findsNothing);
      await tester.pumpWidget(app(() => reports++));
      await tester.pumpAndSettle();
      expect(find.text('Report a problem'), findsOneWidget);
      await tester.tap(find.text('Report a problem'));
      expect(reports, 1);
      expect(tester.takeException(), isNull);
    });
  }
}
