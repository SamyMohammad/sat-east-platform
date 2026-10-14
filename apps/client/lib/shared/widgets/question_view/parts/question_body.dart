import 'package:flutter/material.dart';

import 'package:sat_east_client/core/math_render/math_text.dart';
import 'package:sat_east_client/core/theme/booklet_tokens.dart';
import 'package:sat_east_client/shared/widgets/question_view/answer_state.dart';
import 'package:sat_east_client/shared/widgets/question_view/parts/choice_list.dart';
import 'package:sat_east_client/shared/widgets/question_view/parts/exercise_header.dart';
import 'package:sat_east_client/shared/widgets/question_view/parts/hint_panel.dart';
import 'package:sat_east_client/shared/widgets/question_view/parts/margin_note.dart';
import 'package:sat_east_client/shared/widgets/question_view/parts/spr_answer_area.dart';
import 'package:sat_east_client/shared/widgets/question_view/parts/worked_example.dart';
import 'package:sat_east_client/shared/widgets/question_view/practice_feedback.dart';
import 'package:sat_east_client/shared/widgets/question_view/question_data.dart';
import 'package:sat_east_client/shared/widgets/question_view/question_view_mode.dart';
import 'package:sat_east_client/shared/widgets/spr_input.dart';

/// Scrollable body: exercise header, stem, figures, answer area and the
/// feedback blocks. At `expanded` the margin note is a 300 px aside.
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
    this.figureBuilder,
  });

  final QuestionData question;
  final QuestionViewMode mode;
  final AnswerState answer;
  final BookletLayout layout;
  final ValueChanged<String>? onSelect;
  final ValueChanged<String>? onEliminate;
  final ValueChanged<String>? onRestore;
  final ValueChanged<String>? onSprChanged;
  final Widget Function(BuildContext, String path)? figureBuilder;

  static const double _gap = BookletSpace.s5;

  bool get _interactive => switch (mode) {
    HomeworkMode() => true,
    PracticeMode(:final feedback) => feedback is Idle || feedback is FirstMiss,
  };

  SprInputState get _sprState => switch (mode) {
    PracticeMode(:final feedback) => switch (feedback) {
      Correct() => SprInputState.correct,
      Revealed() => SprInputState.incorrect,
      Checking() => SprInputState.disabled,
      Idle() || FirstMiss() => SprInputState.editable,
    },
    HomeworkMode() => SprInputState.editable,
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
            note: noteOf(MarginNoteTone.correct, noteMd ?? '', noteAuthor),
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
    final aside = layout == BookletLayout.expanded;
    final parts = _feedbackParts(inline: !aside);
    final theme = Theme.of(context);

    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: _gap,
      children: [
        ExerciseHeader(
          label: question.label,
          difficulty: question.difficulty,
          skill: question.skill,
        ),
        MathText(question.stemMd, style: theme.textTheme.bodyLarge),
        if (figureBuilder case final build?)
          for (final path in question.imagePaths) build(context, path),
        _answerArea(),
        if (!aside && parts.note != null) parts.note!,
        if (parts.hint != null) HintPanel(md: parts.hint!),
        if (parts.explanation != null)
          WorkedExample(label: question.label, md: parts.explanation!),
      ],
    );

    final compact = layout == BookletLayout.compact;
    final Widget content = aside
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: BookletSize.questionColumn,
                  ),
                  child: column,
                ),
              ),
              const SizedBox(width: BookletSpace.s8),
              SizedBox(width: BookletSize.marginNote, child: parts.note),
            ],
          )
        : column;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        compact ? BookletSpace.s4 : BookletSpace.s8,
        BookletSpace.s6,
        compact ? BookletSpace.s4 : BookletSpace.s8,
        BookletSpace.s8,
      ),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: aside
                ? BookletSize.questionColumn +
                      BookletSpace.s8 +
                      BookletSize.marginNote
                : BookletSize.questionColumn,
          ),
          child: content,
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
        interactive: _interactive,
        onSelect: onSelect,
        onEliminate: onEliminate,
        onRestore: onRestore,
      ),
      SprKind() => SprAnswerArea(
        key: ValueKey(question.id),
        text: answer.sprText,
        state: _sprState,
        useKeypad: layout == BookletLayout.compact,
        correctAnswer: _sprKey,
        onChanged: _interactive ? onSprChanged : null,
      ),
    };
  }
}
