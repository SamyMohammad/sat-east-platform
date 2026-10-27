@Tags(['golden'])
library;

import 'dart:async';

import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:sat_east_client/shared/widgets/question_view/answer_state.dart';
import 'package:sat_east_client/shared/widgets/question_view/parts/feedback_dock.dart';
import 'package:sat_east_client/shared/widgets/question_view/practice_feedback.dart';
import 'package:sat_east_client/shared/widgets/question_view/question_data.dart';
import 'package:sat_east_client/shared/widgets/question_view/question_view.dart';
import 'package:sat_east_client/shared/widgets/question_view/question_view_mode.dart';
import 'package:sat_east_client/shared/widgets/question_view/quiz_time_up_dialog.dart';

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
          'Add 7 to both sides, then divide by 3.',
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

const _quizAnswered = {0, 1, 2, 3, 4, 5, 7, 8, 10, 11};

Widget _quizView({
  required int index,
  required Duration remaining,
  AnswerState answer = const AnswerState(),
  bool timerHidden = false,
  Set<int> marked = const {4},
}) => Scaffold(
  body: QuestionView(
    title: 'Quiz · 4.2 Linear equations',
    question: _question,
    mode: QuizMode(
      title: 'Quiz 4.2',
      index: index,
      total: 12,
      remaining: remaining,
      timeBudget: const Duration(minutes: 18),
      warnAt: const Duration(minutes: 5),
      timerHidden: timerHidden,
      answered: _quizAnswered,
      marked: marked,
    ),
    answer: answer,
    onBack: () {},
    onSelect: (_) {},
    onEliminate: (_) {},
    onRestore: (_) {},
    onNext: () {},
    onPrev: () {},
    onMark: () {},
    onJumpTo: (_) {},
    onSubmit: () {},
    onToggleTimer: () {},
  ),
);

const _quizAnswer = AnswerState(selected: 'B', eliminated: {'D'});

Future<void> _openNavigator(WidgetTester tester) async {
  await tester.tap(find.textContaining('Question 4 of 12'));
}

void _quizGoldens(Brightness brightness) {
  for (final width in [360.0, 1280.0]) {
    final w = width.toInt();
    testWidgets('F-4: golden qv_quiz_$w', (tester) async {
      await _golden(
        tester,
        brightness: brightness,
        name: 'qv_quiz_$w',
        width: width,
        height: 800,
        child: _quizView(
          index: 3,
          remaining: const Duration(minutes: 14, seconds: 30),
          answer: _quizAnswer,
        ),
      );
    });
    testWidgets('F-4: golden qv_quiz_warning_$w', (tester) async {
      await _golden(
        tester,
        brightness: brightness,
        name: 'qv_quiz_warning_$w',
        width: width,
        height: 800,
        child: _quizView(
          index: 10,
          remaining: const Duration(minutes: 4, seconds: 41),
          answer: const AnswerState(selected: 'A', marked: true),
          marked: const {4, 10},
        ),
      );
    });
    testWidgets('F-4: golden qv_quiz_navigator_$w', (tester) async {
      await _golden(
        tester,
        brightness: brightness,
        name: 'qv_quiz_navigator_$w',
        width: width,
        height: 800,
        child: _quizView(
          index: 3,
          remaining: const Duration(minutes: 14, seconds: 30),
          answer: _quizAnswer,
        ),
        interact: _openNavigator,
      );
    });
  }

  testWidgets('F-4: golden qv_quiz_timer_hidden_1280', (tester) async {
    await _golden(
      tester,
      brightness: brightness,
      name: 'qv_quiz_timer_hidden_1280',
      width: 1280,
      height: 800,
      child: _quizView(
        index: 3,
        remaining: const Duration(minutes: 14, seconds: 30),
        answer: _quizAnswer,
        timerHidden: true,
      ),
    );
  });

  testWidgets('F-4: golden qv_quiz_submit_1280', (tester) async {
    await _golden(
      tester,
      brightness: brightness,
      name: 'qv_quiz_submit_1280',
      width: 1280,
      height: 800,
      child: _quizView(
        index: 3,
        remaining: const Duration(minutes: 14, seconds: 30),
        answer: _quizAnswer,
      ),
      interact: (tester) async {
        await _openNavigator(tester);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Submit quiz').last);
      },
    );
  });

  testWidgets('F-4: golden qv_quiz_timeup_360', (tester) async {
    await _golden(
      tester,
      brightness: brightness,
      name: 'qv_quiz_timeup_360',
      width: 360,
      height: 800,
      child: _quizView(index: 3, remaining: Duration.zero, answer: _quizAnswer),
      interact: (tester) async {
        unawaited(
          showQuizTimeUpDialog(
            tester.element(find.byType(QuestionView)),
            title: 'Quiz 4.2',
            answered: 10,
            onContinue: () {},
          ),
        );
      },
    );
  });
}

void _viewGoldens(Brightness brightness) {
  _quizGoldens(brightness);
  for (final width in [360.0, 1280.0]) {
    for (final entry in _practiceCases.entries) {
      final name = '${entry.key}_${width.toInt()}';
      testWidgets('F-4: golden $name', (tester) async {
        await _golden(
          tester,
          brightness: brightness,
          name: name,
          width: width,
          height: 800,
          child: _practiceView(entry.value.$1, entry.value.$2),
        );
      });
    }

    final homeworkName = 'qv_homework_${width.toInt()}';
    testWidgets('F-4: golden $homeworkName', (tester) async {
      await _golden(
        tester,
        brightness: brightness,
        name: homeworkName,
        width: width,
        height: 800,
        child: _homeworkView(),
      );
    });
  }

  testWidgets('F-4: golden qv_practice_first_miss_360_text2x', (tester) async {
    final (feedback, answer) = _practiceCases['qv_practice_first_miss']!;
    await _golden(
      tester,
      brightness: brightness,
      name: 'qv_practice_first_miss_360_text2x',
      width: 360,
      height: 800,
      textScale: 2,
      child: _practiceView(feedback, answer),
    );
  });
}

Future<void> _golden(
  WidgetTester tester, {
  required Brightness brightness,
  required String name,
  required double width,
  required double height,
  required Widget child,
  double textScale = 1,
  Future<void> Function(WidgetTester)? interact,
}) => expectViewportGolden(
  tester,
  name: brightness == Brightness.dark ? '${name}_dark' : name,
  brightness: brightness,
  width: width,
  height: height,
  child: child,
  textScale: textScale,
  interact: interact,
);

void main() {
  for (final brightness in Brightness.values) {
    group(brightness.name, () => _viewGoldens(brightness));
  }
  for (final variant in [
    'light_360',
    'dark_360',
    'light_360_text2x',
  ]) {
    testWidgets('feedback_dock_$variant', (tester) async {
      await expectViewportGolden(
        tester,
        name: 'feedback_dock_$variant',
        width: 360,
        height: 800,
        brightness: variant.startsWith('dark')
            ? Brightness.dark
            : Brightness.light,
        textScale: variant.endsWith('text2x') ? 2 : 1,
        child: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: FeedbackDock(
              feedback: const Revealed(
                key: McqAnswerKey('B'),
                firstTry: 'A',
                noteMd: 'Divide both sides by 3, then check your answer.',
                explanationMd: r'\(3x=36 \Rightarrow x=12\)',
              ),
              onCheck: null,
              actions: [
                FilledButton(onPressed: () {}, child: const Text('Next')),
              ],
            ),
          ),
        ),
      );
    });
  }
}
