import 'package:flutter/material.dart';

import 'package:sat_east_client/core/theme/booklet_tokens.dart';
import 'package:sat_east_client/shared/widgets/loading_button.dart';
import 'package:sat_east_client/shared/widgets/question_view/answer_state.dart';
import 'package:sat_east_client/shared/widgets/question_view/parts/question_body.dart';
import 'package:sat_east_client/shared/widgets/question_view/parts/question_footer.dart';
import 'package:sat_east_client/shared/widgets/question_view/parts/question_header.dart';
import 'package:sat_east_client/shared/widgets/question_view/parts/save_status_label.dart';
import 'package:sat_east_client/shared/widgets/question_view/practice_feedback.dart';
import 'package:sat_east_client/shared/widgets/question_view/question_data.dart';
import 'package:sat_east_client/shared/widgets/question_view/question_view_mode.dart';

/// The one question screen for practice, homework, quiz and mock. Pure
/// presentation: every decision is made by the caller's Cubit.
class QuestionView extends StatelessWidget {
  const QuestionView({
    required this.title,
    required this.question,
    required this.mode,
    required this.answer,
    super.key,
    this.onBack,
    this.onSelect,
    this.onEliminate,
    this.onRestore,
    this.onSprChanged,
    this.onCheck,
    this.onNext,
    this.onPrev,
    this.onMark,
    this.onJumpTo,
    this.onSubmit,
    this.onRetrySave,
    this.figureBuilder,
  });

  final String title;
  final QuestionData question;
  final QuestionViewMode mode;
  final AnswerState answer;
  final VoidCallback? onBack;
  final ValueChanged<String>? onSelect;
  final ValueChanged<String>? onEliminate;
  final ValueChanged<String>? onRestore;
  final ValueChanged<String>? onSprChanged;
  final VoidCallback? onCheck;
  final VoidCallback? onNext;
  final VoidCallback? onPrev;
  final VoidCallback? onMark;
  final ValueChanged<int>? onJumpTo;
  final VoidCallback? onSubmit;
  final VoidCallback? onRetrySave;
  final Widget Function(BuildContext, String path)? figureBuilder;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = BookletLayout.forWidth(constraints.maxWidth);
        return Column(
          children: [
            _header(),
            Expanded(
              child: QuestionBody(
                question: question,
                mode: mode,
                answer: answer,
                layout: layout,
                onSelect: onSelect,
                onEliminate: onEliminate,
                onRestore: onRestore,
                onSprChanged: onSprChanged,
                figureBuilder: figureBuilder,
              ),
            ),
            _footer(context, layout),
          ],
        );
      },
    );
  }

  Widget _header() => switch (mode) {
    PracticeMode(:final rep, :final repTarget) => QuestionHeader(
      title: title,
      modeLabel: 'Practice',
      progressLabel: 'Rep $rep of $repTarget — Homework unlocks at $repTarget',
      done: rep,
      total: repTarget,
      onBack: onBack,
    ),
    HomeworkMode(
      :final index,
      :final total,
      :final answered,
      :final saveStatus,
    ) =>
      QuestionHeader(
        title: title,
        modeLabel: 'Homework',
        progressLabel: 'Question ${index + 1} of $total',
        done: answered.length,
        total: total,
        current: index,
        onBack: onBack,
        trailing: SaveStatusLabel(status: saveStatus, onRetry: onRetrySave),
      ),
  };

  Widget _footer(BuildContext context, BookletLayout layout) {
    final theme = Theme.of(context);
    final style = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final leading = onPrev == null
        ? null
        : LoadingButton(
            label: 'Back',
            onPressed: onPrev,
            variant: BookletButtonVariant.secondary,
          );
    Widget middle(String text) => Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: style,
    );

    switch (mode) {
      case PracticeMode(:final feedback, :final rep, :final repTarget):
        final done = feedback is Correct || feedback is Revealed;
        final checkEnabled =
            onCheck != null && answer.hasAnswer && !_repeatsMiss(feedback);
        final blockedByMiss = feedback is FirstMiss && !checkEnabled;
        return QuestionFooter(
          leading: leading,
          middle: middle('Rep $rep of $repTarget'),
          helper: blockedByMiss && layout != BookletLayout.compact
              ? 'Pick another answer'
              : null,
          primary: done
              ? LoadingButton(label: 'Next', onPressed: onNext)
              : LoadingButton(
                  label: 'Check',
                  isLoading: feedback is Checking,
                  onPressed: checkEnabled ? onCheck : null,
                ),
        );
      case HomeworkMode(:final index, :final total):
        return QuestionFooter(
          leading: leading,
          middle: middle('Question ${index + 1} of $total'),
          primary: LoadingButton(label: 'Next', onPressed: onNext),
        );
    }
  }

  /// Under `FirstMiss` the same answer cannot be checked twice.
  bool _repeatsMiss(PracticeFeedback feedback) {
    if (feedback is! FirstMiss) return false;
    return switch (question.kind) {
      McqKind() => answer.selected == feedback.missed,
      SprKind() => answer.sprText == feedback.missed,
    };
  }
}
