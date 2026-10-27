import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:sat_east_client/core/theme/app_theme.dart';
import 'package:sat_east_client/shared/widgets/question_view/answer_state.dart';
import 'package:sat_east_client/shared/widgets/question_view/practice_feedback.dart';
import 'package:sat_east_client/shared/widgets/question_view/question_data.dart';
import 'package:sat_east_client/shared/widgets/question_view/question_view.dart';
import 'package:sat_east_client/shared/widgets/question_view/question_view_mode.dart';

const _practice = PracticeMode(feedback: Idle(), rep: 2, repTarget: 10);
const _quiz = QuizMode(
  title: 'Quiz 1.1',
  index: 0,
  total: 2,
  remaining: Duration(minutes: 10),
  timeBudget: Duration(minutes: 10),
  warnAt: Duration(minutes: 1),
);

void main() {
  testWidgets('PRC-01: staging practice target unlocks the quiz', (
    tester,
  ) async {
    await _pump(tester, 'q1', _practice);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            (widget.properties.label?.contains(
                  'Rep 2 of 10 \u2014 Quiz unlocks at 10',
                ) ??
                false),
      ),
      findsOneWidget,
    );
  });

  for (final (label, mode) in [('practice', _practice), ('quiz', _quiz)]) {
    testWidgets('PRC-01: staging new $label question starts at scroll top', (
      tester,
    ) async {
      await _pump(tester, 'q1', mode);
      final scrollable = find.byType(Scrollable).first;
      await tester.drag(scrollable, const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(
        tester.state<ScrollableState>(scrollable).position.pixels,
        greaterThan(0),
      );
      await _pump(tester, 'q2', mode);
      expect(
        tester
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position
            .pixels,
        0,
      );
    });
  }
}

Future<void> _pump(
  WidgetTester tester,
  String id,
  QuestionViewMode mode,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: QuestionView(
          title: 'Linear equations',
          question: QuestionData(
            id: id,
            label: '1.1',
            stemMd: List.filled(
              100,
              'Solve the following equation carefully.',
            ).join(' '),
            kind: const McqKind([
              ChoiceData(label: 'A', md: '1'),
              ChoiceData(label: 'B', md: '2'),
            ]),
          ),
          mode: mode,
          answer: const AnswerState(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
