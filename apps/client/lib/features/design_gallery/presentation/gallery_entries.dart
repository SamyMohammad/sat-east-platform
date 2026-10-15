import 'dart:async';

import 'package:flutter/material.dart';

import 'package:sat_east_client/core/theme/booklet_tokens.dart';
import 'package:sat_east_client/shared/widgets/question_view/answer_state.dart';
import 'package:sat_east_client/shared/widgets/question_view/parts/homework_navigator.dart';
import 'package:sat_east_client/shared/widgets/question_view/parts/question_navigator.dart';
import 'package:sat_east_client/shared/widgets/question_view/parts/submit_dialog.dart';
import 'package:sat_east_client/shared/widgets/question_view/practice_feedback.dart';
import 'package:sat_east_client/shared/widgets/question_view/question_data.dart';
import 'package:sat_east_client/shared/widgets/question_view/question_view.dart';
import 'package:sat_east_client/shared/widgets/question_view/question_view_mode.dart';
import 'package:sat_east_client/shared/widgets/question_view/quiz_time_up_dialog.dart';

/// One state of the shared `QuestionView`, shown by the design gallery.
@immutable
final class GalleryEntry {
  const GalleryEntry({
    required this.id,
    required this.label,
    required this.builder,
    this.openOverlay,
  });

  /// Stable id used in the `entry` query parameter, e.g. `quiz-warning`.
  final String id;

  /// Human label shown in the entry picker.
  final String label;

  /// Returns the `QuestionView` (no Scaffold).
  final WidgetBuilder builder;

  /// Opens the sheet, popover or dialog this entry demonstrates.
  final void Function(BuildContext context)? openOverlay;
}

const _mcq = QuestionData(
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

const _spr = QuestionData(
  id: 'q14',
  label: '4.2 · Ex 14',
  stemMd: 'The line passes through (1, 2) and (4, 4). What is its slope?',
  kind: SprKind(),
);

const _practiceTitle = 'Linear equations';
const _practiceRep = 7;
const _practiceRepTarget = 10;
const _noteAuthor = 'A. Elmenshawy';

const _homeworkTitle = 'Homework 4.2';
const _homeworkIndex = 5;
const _homeworkTotal = 20;
// Every question except 8, 13 and 17.
const _homeworkAnswered = {
  0, 1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 14, 15, 16, 18, 19, //
};
const _homeworkMarked = {2};

const _quizViewTitle = 'Quiz · 4.2 Linear equations';
const _quizTitle = 'Quiz 4.2';
const _quizTotal = 12;
const _quizAnsweredCount = 10;
// Every question except 6 and 9.
const _quizAnswered = {0, 1, 2, 3, 4, 5, 7, 8, 10, 11};
const _quizMarked = {4};
const _quizTimeBudget = Duration(minutes: 18);
const _quizWarnAt = Duration(minutes: 5);
const _quizMidRemaining = Duration(minutes: 14, seconds: 30);
const _quizWarnRemaining = Duration(minutes: 4, seconds: 41);
const _quizMidIndex = 3;
const _quizWarnIndex = 10;
const int _quizLastIndex = _quizTotal - 1;
const _quizAnswer = AnswerState(selected: 'B', eliminated: {'D'});

const _submitTitle = 'Submit quiz?';
const _submitBody = 'After you submit, your answers are locked and marked.';
const _submitLabel = 'Submit quiz';

bool _isPhone(BuildContext context) =>
    BookletLayout.forWidth(MediaQuery.sizeOf(context).width) ==
    BookletLayout.compact;

Widget _practice({
  required PracticeFeedback feedback,
  AnswerState answer = const AnswerState(),
  QuestionData question = _mcq,
}) => QuestionView(
  title: _practiceTitle,
  question: question,
  mode: PracticeMode(
    feedback: feedback,
    rep: _practiceRep,
    repTarget: _practiceRepTarget,
    noteAuthor: _noteAuthor,
  ),
  answer: answer,
  onBack: () {},
  onSelect: (_) {},
  onEliminate: (_) {},
  onRestore: (_) {},
  onSprChanged: (_) {},
  onCheck: () {},
  onNext: () {},
  onPrev: () {},
  onMark: () {},
);

Widget _homework({
  required SaveStatus status,
  AnswerState answer = const AnswerState(),
  QuestionData question = _mcq,
}) => QuestionView(
  title: _homeworkTitle,
  question: question,
  mode: HomeworkMode(
    title: _homeworkTitle,
    index: _homeworkIndex,
    total: _homeworkTotal,
    saveStatus: status,
    answered: _homeworkAnswered,
    marked: _homeworkMarked,
  ),
  answer: answer,
  onBack: () {},
  onSelect: (_) {},
  onEliminate: (_) {},
  onRestore: (_) {},
  onSprChanged: (_) {},
  onNext: () {},
  onPrev: () {},
  onMark: () {},
  onJumpTo: (_) {},
  onSubmit: () {},
  onRetrySave: () {},
);

Widget _quiz({
  int index = _quizMidIndex,
  Duration remaining = _quizMidRemaining,
  AnswerState answer = _quizAnswer,
  bool timerHidden = false,
}) => QuestionView(
  title: _quizViewTitle,
  question: _mcq,
  mode: QuizMode(
    title: _quizTitle,
    index: index,
    total: _quizTotal,
    remaining: remaining,
    timeBudget: _quizTimeBudget,
    warnAt: _quizWarnAt,
    timerHidden: timerHidden,
    answered: _quizAnswered,
    marked: _quizMarked,
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
);

void _openHomeworkNavigator(BuildContext context) {
  if (!_isPhone(context)) return; // wide layouts show the panel inline
  unawaited(
    showHomeworkNavigatorSheet(
      context,
      title: _homeworkTitle,
      total: _homeworkTotal,
      index: _homeworkIndex,
      answered: _homeworkAnswered,
      marked: _homeworkMarked,
      onJumpTo: (_) {},
      onSubmit: () {},
    ),
  );
}

void _openQuizNavigator(BuildContext context) {
  final open = _isPhone(context) ? showNavigatorSheet : showNavigatorPopover;
  unawaited(
    open(
      context,
      title: '$_quizTitle questions',
      total: _quizTotal,
      index: _quizMidIndex,
      answered: _quizAnswered,
      marked: _quizMarked,
      onJumpTo: (_) {},
      submitLabel: _submitLabel,
      onSubmitPressed: () {},
    ),
  );
}

void _openSubmitConfirm(BuildContext context) => unawaited(
  showSubmitConfirmDialog(
    context,
    title: _submitTitle,
    body: _submitBody,
    confirmLabel: _submitLabel,
    total: _quizTotal,
    answered: _quizAnswered,
    onSubmit: () {},
    onJumpTo: (_) {},
  ),
);

void _openTimeUp(BuildContext context) => unawaited(
  showQuizTimeUpDialog(
    context,
    title: _quizTitle,
    answered: _quizAnsweredCount,
    onContinue: () {},
  ),
);

/// The gallery entries, in display order.
final List<GalleryEntry> galleryEntries = [
  GalleryEntry(
    id: 'practice-idle',
    label: 'Practice · Idle',
    builder: (_) => _practice(feedback: const Idle()),
  ),
  GalleryEntry(
    id: 'practice-checking',
    label: 'Practice · Checking',
    builder: (_) => _practice(
      feedback: const Checking(),
      answer: const AnswerState(selected: 'B'),
    ),
  ),
  GalleryEntry(
    id: 'practice-first-miss',
    label: 'Practice · First miss',
    builder: (_) => _practice(
      feedback: const FirstMiss(
        missed: 'A',
        noteMd:
            r'Not quite. Watch what happens to \(-7\) when it crosses the '
            'equals sign.',
        hintMd: 'Undo the subtraction first, then the multiplication.',
      ),
      answer: const AnswerState(selected: 'A'),
    ),
  ),
  GalleryEntry(
    id: 'practice-correct',
    label: 'Practice · Correct',
    builder: (_) => _practice(
      feedback: const Correct(
        noteMd: 'Right. Isolate the variable term first, then divide.',
        explanationMd:
            'Add 7 to both sides, then divide by 3.'
            '\n\n'
            r'\[3x = 36 \quad\Rightarrow\quad x = 12\]',
      ),
      answer: const AnswerState(selected: 'B'),
    ),
  ),
  GalleryEntry(
    id: 'practice-revealed',
    label: 'Practice · Revealed',
    builder: (_) => _practice(
      feedback: const Revealed(
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
      answer: const AnswerState(selected: 'C'),
    ),
  ),
  GalleryEntry(
    id: 'practice-revealed-spr',
    label: 'Practice · Revealed (SPR)',
    builder: (_) => _practice(
      question: _spr,
      feedback: const Revealed(key: SprAnswerKey('2/3'), firstTry: '3/2'),
      answer: const AnswerState(sprText: '1.5'),
    ),
  ),
  GalleryEntry(
    id: 'homework-saved',
    label: 'Homework · Saved',
    builder: (_) => _homework(
      status: SaveStatus.saved,
      answer: const AnswerState(selected: 'B'),
    ),
  ),
  GalleryEntry(
    id: 'homework-saving',
    label: 'Homework · Saving',
    builder: (_) => _homework(
      status: SaveStatus.saving,
      question: _spr,
      answer: const AnswerState(sprText: '2/3'),
    ),
  ),
  GalleryEntry(
    id: 'homework-offline',
    label: 'Homework · Offline',
    builder: (_) => _homework(status: SaveStatus.offline),
  ),
  GalleryEntry(
    id: 'homework-failed',
    label: "Homework · Couldn't save",
    builder: (_) => _homework(status: SaveStatus.failed),
  ),
  GalleryEntry(
    id: 'homework-navigator',
    label: 'Homework · Navigator',
    builder: (_) => _homework(status: SaveStatus.saved),
    openOverlay: _openHomeworkNavigator,
  ),
  GalleryEntry(id: 'quiz', label: 'Quiz · Question', builder: (_) => _quiz()),
  GalleryEntry(
    id: 'quiz-warning',
    label: 'Quiz · 5-min warning',
    builder: (_) => _quiz(
      index: _quizWarnIndex,
      remaining: _quizWarnRemaining,
      answer: const AnswerState(selected: 'A', marked: true),
    ),
  ),
  GalleryEntry(
    id: 'quiz-timer-hidden',
    label: 'Quiz · Timer hidden',
    builder: (_) => _quiz(timerHidden: true),
  ),
  GalleryEntry(
    id: 'quiz-navigator',
    label: 'Quiz · Navigator',
    builder: (_) => _quiz(),
    openOverlay: _openQuizNavigator,
  ),
  GalleryEntry(
    id: 'quiz-submit',
    label: 'Quiz · Submit confirm',
    builder: (_) => _quiz(index: _quizLastIndex),
    openOverlay: _openSubmitConfirm,
  ),
  GalleryEntry(
    id: 'quiz-time-up',
    label: "Quiz · Time's up",
    builder: (_) => _quiz(remaining: Duration.zero),
    openOverlay: _openTimeUp,
  ),
];

/// The entry with [id]; unknown, empty or null ids give the first entry.
GalleryEntry galleryEntryById(String? id) => galleryEntries.firstWhere(
  (e) => e.id == id,
  orElse: () => galleryEntries.first,
);
