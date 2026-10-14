@Tags(['golden'])
library;

import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:sat_east_client/shared/widgets/question_view/answer_state.dart';
import 'package:sat_east_client/shared/widgets/question_view/practice_feedback.dart';
import 'package:sat_east_client/shared/widgets/question_view/question_data.dart';
import 'package:sat_east_client/shared/widgets/question_view/question_view.dart';
import 'package:sat_east_client/shared/widgets/question_view/question_view_mode.dart';

import '../full_viewport_harness.dart';

const _question = QuestionData(
  id: 'q7',
  label: '4.2 · Ex 7',
  stemMd: r'Solve for \(x\): \(3x - 7 = 29\)',
  kind: McqKind([
    ChoiceData(label: 'A', md: r'\(x = 7\)'),
    ChoiceData(label: 'B', md: r'\(x = 12\)'),
    ChoiceData(label: 'C', md: r'\(x = \frac{22}{3}\)'),
    ChoiceData(label: 'D', md: r'\(x = 36\)'),
  ]),
  difficulty: QuestionDifficulty.easy,
  skill: 'Linear equations',
);

PracticeMode _practice(PracticeFeedback feedback) => PracticeMode(
  feedback: feedback,
  rep: 7,
  repTarget: 10,
  noteAuthor: 'A. Elmenshawy',
);

const _answered = {0, 1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 14, 15, 16};

final _practiceCases = <String, (PracticeFeedback, AnswerState)>{
  'qv_practice_idle': (const Idle(), const AnswerState()),
  'qv_practice_first_miss': (
    const FirstMiss(
      missed: 'A',
      noteMd:
          r'Not quite. Watch what happens to \(-7\) when it crosses the '
          'equals sign.',
      hintMd: 'Undo the subtraction first, then the multiplication.',
    ),
    const AnswerState(selected: 'A'),
  ),
  'qv_practice_correct': (
    const Correct(
      noteMd: 'Right. Isolate the variable term first, then divide.',
      explanationMd:
          'Add 7 to both sides, then divide by 3.'
          '\n\n'
          r'\[3x = 36 \quad\Rightarrow\quad x = 12\]',
    ),
    const AnswerState(selected: 'B'),
  ),
  'qv_practice_revealed': (
    const Revealed(
      key: McqAnswerKey('B'),
      firstTry: 'A',
      noteMd:
          r'The answer is 12. Twice now the \(-7\) kept its sign as it '
          'crossed the equals sign.',
      explanationMd:
          r'Add 7 to both sides: \(3x = 36\), so \(x = 12\).'
          '\n\n'
          'نضيف ٧ إلى الطرفين ثم نقسم على ٣.',
    ),
    const AnswerState(selected: 'C'),
  ),
};

Widget _practiceView(PracticeFeedback feedback, AnswerState answer) => Scaffold(
  body: QuestionView(
    title: 'Linear equations',
    question: _question,
    mode: _practice(feedback),
    answer: answer,
    onBack: () {},
    onSelect: (_) {},
    onEliminate: (_) {},
    onRestore: (_) {},
    onCheck: () {},
    onNext: () {},
  ),
);

Widget _homeworkView() => Scaffold(
  body: QuestionView(
    title: 'Homework 4.2',
    question: _question,
    mode: const HomeworkMode(
      title: 'Homework 4.2',
      index: 5,
      total: 20,
      saveStatus: SaveStatus.saved,
      answered: _answered,
      marked: {2},
    ),
    answer: const AnswerState(),
    onBack: () {},
    onSelect: (_) {},
    onEliminate: (_) {},
    onRestore: (_) {},
    onNext: () {},
    onPrev: () {},
    onJumpTo: (_) {},
    onSubmit: () {},
    onRetrySave: () {},
  ),
);

void main() {
  for (final width in [360.0, 1280.0]) {
    for (final entry in _practiceCases.entries) {
      final name = '${entry.key}_${width.toInt()}';
      testWidgets('F-4: golden $name', (tester) async {
        await expectViewportGolden(
          tester,
          name: name,
          width: width,
          height: 800,
          child: _practiceView(entry.value.$1, entry.value.$2),
        );
      });
    }

    final homeworkName = 'qv_homework_${width.toInt()}';
    testWidgets('F-4: golden $homeworkName', (tester) async {
      await expectViewportGolden(
        tester,
        name: homeworkName,
        width: width,
        height: 800,
        child: _homeworkView(),
      );
    });
  }

  testWidgets('F-4: golden qv_practice_first_miss_360_text2x', (tester) async {
    final (feedback, answer) = _practiceCases['qv_practice_first_miss']!;
    await expectViewportGolden(
      tester,
      name: 'qv_practice_first_miss_360_text2x',
      width: 360,
      height: 800,
      textScale: 2,
      child: _practiceView(feedback, answer),
    );
  });
}
