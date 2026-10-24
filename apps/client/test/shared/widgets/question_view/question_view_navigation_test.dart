import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/math_render/math_text.dart';
import 'package:sat_east_client/core/theme/app_theme.dart';
import 'package:sat_east_client/shared/widgets/choice_tile.dart';
import 'package:sat_east_client/shared/widgets/question_view/answer_state.dart';
import 'package:sat_east_client/shared/widgets/question_view/parts/exam_bar.dart';
import 'package:sat_east_client/shared/widgets/question_view/parts/question_footer.dart';
import 'package:sat_east_client/shared/widgets/question_view/parts/question_header.dart';
import 'package:sat_east_client/shared/widgets/question_view/parts/worked_example.dart';
import 'package:sat_east_client/shared/widgets/question_view/practice_feedback.dart';
import 'package:sat_east_client/shared/widgets/question_view/question_data.dart';
import 'package:sat_east_client/shared/widgets/question_view/question_view.dart';
import 'package:sat_east_client/shared/widgets/question_view/question_view_mode.dart';

const _question = QuestionData(
  id: 'q1',
  label: 'Preview',
  stemMd: 'Solve x.',
  kind: McqKind([
    ChoiceData(label: 'A', md: 'One'),
    ChoiceData(label: 'B', md: 'Two'),
  ]),
);

void main() {
  for (final width in [360.0, 1280.0]) {
    for (final mode in <QuestionViewMode>[
      const PracticeMode(
        feedback: Correct(explanationMd: 'Because two.'),
        rep: 1,
        repTarget: 1,
      ),
      const HomeworkMode(
        title: 'Homework',
        index: 0,
        total: 2,
        saveStatus: SaveStatus.saved,
      ),
      const QuizMode(
        title: 'Quiz',
        index: 0,
        total: 2,
        remaining: Duration(minutes: 4),
        timeBudget: Duration(minutes: 5),
        warnAt: Duration(minutes: 1),
      ),
    ]) {
      testWidgets('F-4: navigation hidden for ${mode.runtimeType} at $width', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 1000);
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: QuestionView(
                title: 'Preview',
                question: _question,
                mode: mode,
                answer: const AnswerState(selected: 'B'),
                showNavigation: false,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.textContaining('Rep '), findsNothing);
        expect(find.text('Next'), findsNothing);
        expect(find.byTooltip('Back to topic'), findsNothing);
        expect(find.byType(QuestionHeader), findsNothing);
        expect(find.byType(ExamBar), findsNothing);
        expect(find.byType(QuestionFooter), findsNothing);
        expect(find.byType(ChoiceTile), findsNWidgets(2));
        expect(
          find.byWidgetPredicate(
            (w) => w is MathText && w.source == 'Solve x.',
          ),
          findsOneWidget,
        );
        if (mode is PracticeMode) {
          expect(
            tester.widget<WorkedExample>(find.byType(WorkedExample)).md,
            'Because two.',
          );
        }
        expect(tester.takeException(), isNull);
      });
    }
  }
}
