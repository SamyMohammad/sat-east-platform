import 'package:flutter/material.dart';
import 'package:sat_east_client/core/math_render/math_text.dart';
import 'package:sat_east_client/core/theme/app_tokens.dart';
import 'package:sat_east_client/core/theme/app_type.dart';
import 'package:sat_east_client/shared/widgets/question_view/answer_state.dart';
import 'package:sat_east_client/shared/widgets/question_view/parts/choice_list.dart';
import 'package:sat_east_client/shared/widgets/question_view/parts/exercise_header.dart';
import 'package:sat_east_client/shared/widgets/question_view/parts/hint_panel.dart';
import 'package:sat_east_client/shared/widgets/question_view/parts/margin_note.dart';
import 'package:sat_east_client/shared/widgets/question_view/parts/practice_question_layout.dart';
import 'package:sat_east_client/shared/widgets/question_view/parts/quiz_question_header.dart';
import 'package:sat_east_client/shared/widgets/question_view/parts/spr_answer_area.dart';
import 'package:sat_east_client/shared/widgets/question_view/parts/worked_example.dart';
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
    this.showInlineFeedback = false,
  });

  final bool showInlineFeedback;
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

  /// Note, hint and explanation for the current feedback (rulings R1, R3).
  ({MarginNote? note, String? hint, String? explanation}) _feedbackParts({
    required bool inline,
  }) {
    MarginNote noteOf(MarginNoteTone tone, String body, String? author) =>
        MarginNote(tone: tone, author: author, bodyMd: body, inline: inline);
    if (mode case PracticeMode(:final feedback, :final noteAuthor)) {
      switch (feedback) {
        case FirstMiss(:final noteMd, :final hintMd):
          final body = noteMd ?? hintMd;
          return (
            note: body == null
                ? null
                : noteOf(MarginNoteTone.miss, body, noteAuthor),
            hint: noteMd == null ? null : hintMd,
            explanation: null,
          );
        case Correct(:final noteMd, :final explanationMd):
          return (
            note: noteMd == null || noteMd.isEmpty
                ? null
                : noteOf(MarginNoteTone.correct, noteMd, noteAuthor),
            hint: null,
            explanation: explanationMd,
          );
        case Revealed(:final noteMd, :final explanationMd):
          return (
            note: noteMd == null
                ? null
                : noteOf(MarginNoteTone.miss, noteMd, noteAuthor),
            hint: null,
            explanation: explanationMd,
          );
        case Idle() || Checking():
          break;
      }
    }
    return (note: null, hint: null, explanation: null);
  }

  @override
  Widget build(BuildContext context) {
    final parts = _feedbackParts(inline: true);
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
        if (showInlineFeedback) ...[
          ?parts.note,
          if (parts.hint case final hint?) HintPanel(md: hint),
        ] else if (mode case PracticeMode(
          feedback: FirstMiss(noteMd: String(), hintMd: final hint?),
        ))
          HintPanel(md: hint),
        // The pinned dock holds only the verdict, the teacher line and the
        // actions, so the worked example lives below the choices.
        if (parts.explanation case final explanation?)
          WorkedExample(label: question.label, md: explanation),
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
