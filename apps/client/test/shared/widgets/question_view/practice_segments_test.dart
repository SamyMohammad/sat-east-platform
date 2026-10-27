import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/theme/app_colors.dart';
import 'package:sat_east_client/core/theme/app_theme.dart';
import 'package:sat_east_client/shared/widgets/question_view/answer_state.dart';
import 'package:sat_east_client/shared/widgets/question_view/practice_feedback.dart';
import 'package:sat_east_client/shared/widgets/question_view/question_data.dart';
import 'package:sat_east_client/shared/widgets/question_view/question_view.dart';
import 'package:sat_east_client/shared/widgets/question_view/question_view_mode.dart';
import 'package:sat_east_client/shared/widgets/question_view/rep_outcome.dart';

const _question = QuestionData(
  id: 'q1',
  label: '4.2 · Ex 7',
  stemMd: r'Solve $2x + 3 = 7$.',
  kind: McqKind([
    ChoiceData(label: 'A', md: 'One'),
    ChoiceData(label: 'B', md: 'Two'),
  ]),
);

Future<BuildContext> _pump(
  WidgetTester t, {
  required int rep,
  List<RepOutcome> outcomes = const [],
}) async {
  t.view.physicalSize = const Size(360, 800);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: QuestionView(
          title: 'Linear equations',
          question: _question,
          mode: PracticeMode(
            feedback: const Idle(),
            rep: rep,
            repTarget: 6,
            outcomes: outcomes,
          ),
          answer: const AnswerState(),
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
  return t.element(find.byType(QuestionView));
}

BoxDecoration _deco(WidgetTester t, int i) =>
    t
            .widget<AnimatedContainer>(
              find.byKey(ValueKey('progress-segment-$i')),
            )
            .decoration!
        as BoxDecoration;

void main() {
  testWidgets('PRC-03: segments show first try, missed, current, unanswered', (
    t,
  ) async {
    final context = await _pump(
      t,
      rep: 4,
      outcomes: const [
        RepOutcome.firstTry,
        RepOutcome.missed,
        RepOutcome.firstTry,
      ],
    );
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;

    expect(_deco(t, 0).color, colors.correct);
    expect(_deco(t, 1).color, colors.incorrect);
    expect(_deco(t, 2).color, colors.correct);
    expect(_deco(t, 3).color, scheme.primaryContainer);
    expect(_deco(t, 3).border, isNotNull);
    expect(_deco(t, 4).color, scheme.outlineVariant);
    expect(_deco(t, 5).color, scheme.outlineVariant);
  });

  testWidgets('PRC-03: the current rep is not pre-filled', (t) async {
    final context = await _pump(t, rep: 1);
    final scheme = Theme.of(context).colorScheme;

    expect(_deco(t, 0).color, scheme.primaryContainer);
    expect(_deco(t, 0).color, isNot(scheme.primary));
  });

  testWidgets('PRC-03: reps without an outcome fill with the brand colour', (
    t,
  ) async {
    final context = await _pump(t, rep: 4);
    final scheme = Theme.of(context).colorScheme;

    for (final i in [0, 1, 2]) {
      expect(_deco(t, i).color, scheme.primary);
    }
    expect(_deco(t, 3).color, scheme.primaryContainer);
  });

  testWidgets('PRC-03: segment bar has a text label, not colour alone', (
    t,
  ) async {
    final semantics = t.ensureSemantics();
    await _pump(
      t,
      rep: 4,
      outcomes: const [
        RepOutcome.firstTry,
        RepOutcome.missed,
        RepOutcome.firstTry,
      ],
    );

    expect(
      find.bySemanticsLabel('2 of 6 reps correct on the first try'),
      findsOneWidget,
    );
    expect(find.text('Rep 4 of 6 \u2014 Quiz unlocks at 6'), findsOneWidget);
    semantics.dispose();
  });
}
