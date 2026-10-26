import 'package:flutter/material.dart';

import 'package:sat_east_client/core/math_render/math_text.dart';
import 'package:sat_east_client/core/theme/app_tokens.dart';
import 'package:sat_east_client/core/theme/app_type.dart';
import 'package:sat_east_client/shared/widgets/question_view/answer_state.dart';
import 'package:sat_east_client/shared/widgets/question_view/parts/choice_list.dart';
import 'package:sat_east_client/shared/widgets/question_view/parts/exercise_header.dart';
import 'package:sat_east_client/shared/widgets/question_view/parts/hint_panel.dart';
import 'package:sat_east_client/shared/widgets/question_view/parts/practice_question_layout.dart';
import 'package:sat_east_client/shared/widgets/question_view/parts/quiz_question_header.dart';
import 'package:sat_east_client/shared/widgets/question_view/parts/spr_answer_area.dart';
import 'package:sat_east_client/shared/widgets/question_view/practice_feedback.dart';
import 'package:sat_east_client/shared/widgets/question_view/question_data.dart';
import 'package:sat_east_client/shared/widgets/question_view/question_view_mode.dart';
import 'package:sat_east_client/shared/widgets/spr_input.dart';

/// Scrollable question column shared by every mode; practice feedback lives
/// in the pinned dock.
class QuestionBody extends StatelessWidget {
  const QuestionBody({
    required this.question,
    required this.mode,
    required this.answer,
    required this.layout,
    super.key,
    this.onSelect,
    this.onEliminate,
    this.onRestore,
    this.onSprChanged,
    this.onMark,
    this.figureBuilder,
  });

  final QuestionData question;
  final QuestionViewMode mode;
  final AnswerState answer;
  final AppLayout layout;
  final ValueChanged<String>? onSelect;
  final ValueChanged<String>? onEliminate;
  final ValueChanged<String>? onRestore;
  final ValueChanged<String>? onSprChanged;
  final VoidCallback? onMark;
  final Widget Function(BuildContext, String path)? figureBuilder;

  static const double _gap = AppSpace.s5;

  SprInputState get _sprState => switch (mode) {
    PracticeMode(:final feedback) => switch (feedback) {
      Correct() => SprInputState.correct,
      Revealed() => SprInputState.incorrect,
      Checking() => SprInputState.disabled,
      Idle() || FirstMiss() => SprInputState.editable,
    },
    HomeworkMode() => SprInputState.editable,
    QuizMode() =>
      mode.isTimeUp ? SprInputState.disabled : SprInputState.editable,
  };

  String? get _sprKey => switch (mode) {
    PracticeMode(feedback: Revealed(key: SprAnswerKey(:final text))) => text,
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: _gap,
      children: [
        switch (mode) {
          QuizMode(:final index) => QuizQuestionHeader(
            number: index + 1,
            marked: answer.marked,
            onMark: mode.markAction(onMark),
          ),
          PracticeMode() || HomeworkMode() => ExerciseHeader(
            label: question.label,
            difficulty: question.difficulty,
            skill: question.skill,
          ),
        },
        MathText(
          question.stemMd,
          style: layout == AppLayout.compact
              ? AppType.stemCompact
              : AppType.stem,
        ),
        if (figureBuilder case final build?)
          for (final path in question.imagePaths) build(context, path),
        _answerArea(),
        if (mode case PracticeMode(
          feedback: FirstMiss(noteMd: String(), hintMd: final hint?),
        ))
          HintPanel(md: hint),
      ],
    );

    return _QuestionScroll(
      questionId: question.id,
      layout: layout,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppSize.questionColumn,
          ),
          child: column,
        ),
      ),
    );
  }

  Widget _answerArea() {
    return switch (question.kind) {
      McqKind(:final choices) => ChoiceList(
        choices: choices,
        answer: answer,
        mode: mode,
        interactive: mode.choicesInteractive,
        onSelect: onSelect,
        onEliminate: onEliminate,
        onRestore: onRestore,
      ),
      SprKind() => SprAnswerArea(
        key: ValueKey(question.id),
        text: answer.sprText,
        state: _sprState,
        useKeypad: layout == AppLayout.compact,
        correctAnswer: _sprKey,
        onChanged: mode.choicesInteractive ? onSprChanged : null,
      ),
    };
  }
}

class _QuestionScroll extends StatelessWidget {
  const _QuestionScroll({
    required this.questionId,
    required this.layout,
    required this.child,
  });

  final String questionId;
  final AppLayout layout;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final compact = layout == AppLayout.compact;
    return SingleChildScrollView(
      key: ValueKey(questionId),
      padding: EdgeInsets.fromLTRB(
        compact ? AppSpace.s5 : AppSpace.s6,
        compact ? AppSpace.s4 : AppSpace.s12,
        compact ? AppSpace.s5 : AppSpace.s6,
        AppSpace.s8 + PracticeQuestionLayout.bottomInsetOf(context),
      ),
      child: child,
    );
  }
}
