import 'dart:async';

import 'package:flutter/material.dart';

import 'package:sat_east_client/core/theme/app_icons.dart';
import 'package:sat_east_client/core/theme/booklet_tokens.dart';
import 'package:sat_east_client/shared/widgets/loading_button.dart';
import 'package:sat_east_client/shared/widgets/question_view/answer_state.dart';
import 'package:sat_east_client/shared/widgets/question_view/parts/exam_bar.dart';
import 'package:sat_east_client/shared/widgets/question_view/parts/homework_navigator.dart';
import 'package:sat_east_client/shared/widgets/question_view/parts/question_body.dart';
import 'package:sat_east_client/shared/widgets/question_view/parts/question_footer.dart';
import 'package:sat_east_client/shared/widgets/question_view/parts/question_header.dart';
import 'package:sat_east_client/shared/widgets/question_view/parts/question_navigator.dart';
import 'package:sat_east_client/shared/widgets/question_view/parts/question_shortcuts.dart';
import 'package:sat_east_client/shared/widgets/question_view/parts/save_status_label.dart';
import 'package:sat_east_client/shared/widgets/question_view/parts/submit_dialog.dart';
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
    this.onToggleTimer,
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

  /// Hide / Show timer (quiz, wide layouts only).
  final VoidCallback? onToggleTimer;
  final Widget Function(BuildContext, String path)? figureBuilder;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = BookletLayout.forWidth(constraints.maxWidth);
        return QuestionShortcuts(
          labels: switch (question.kind) {
            McqKind(:final choices) => [for (final c in choices) c.label],
            SprKind() => const <String>[],
          },
          choicesInteractive: mode.choicesInteractive,
          onSelect: onSelect,
          onEliminate: onEliminate,
          onMark: mode.markAction(onMark),
          onPrev: mode.backAction(onPrev),
          onNext: mode.forwardAction(onNext),
          child: Column(
            children: [
              _header(context, layout),
              Expanded(child: _bodyWithPanel(layout)),
              _footer(context, layout),
            ],
          ),
        );
      },
    );
  }

  Widget _bodyWithPanel(BookletLayout layout) {
    final body = QuestionBody(
      question: question,
      mode: mode,
      answer: answer,
      layout: layout,
      onSelect: onSelect,
      onEliminate: onEliminate,
      onRestore: onRestore,
      onSprChanged: onSprChanged,
      onMark: onMark,
      figureBuilder: figureBuilder,
    );
    if (mode case HomeworkMode(
      :final title,
      :final index,
      :final total,
      :final answered,
      :final marked,
    ) when layout != BookletLayout.compact) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: body),
          HomeworkNavigatorPanel(
            title: title,
            total: total,
            index: index,
            answered: answered,
            marked: marked,
            onJumpTo: onJumpTo,
            onSubmit: onSubmit,
          ),
        ],
      );
    }
    return body;
  }

  Widget _header(BuildContext context, BookletLayout layout) => switch (mode) {
    PracticeMode(:final rep, :final repTarget) => QuestionHeader(
      title: title,
      modeLabel: 'Practice',
      progressLabel: 'Rep $rep of $repTarget — Quiz unlocks at $repTarget',
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
        modeLabel: 'Homework · $total questions',
        progressLabel: '${answered.length} of $total answered',
        done: answered.length,
        total: total,
        current: index,
        onBack: onBack,
        trailing: SaveStatusLabel(status: saveStatus, onRetry: onRetrySave),
      ),
    final QuizMode quiz => Column(
      children: [
        ExamBar(
          title: title,
          shortTitle: quiz.title,
          subtitle: '${quiz.total} questions',
          remaining: quiz.remaining,
          timeBudget: quiz.timeBudget,
          warning: quiz.isWarning,
          timerHidden: quiz.timerHidden,
          compact: layout == BookletLayout.compact,
          onToggleTimer: onToggleTimer,
        ),
        if (quiz.showsWarningBanner)
          ExamWarningBanner(
            warnAt: quiz.warnAt,
            onReviewMarked: quiz.marked.isEmpty
                ? null
                : () => _openNavigator(context, layout, quiz),
          ),
      ],
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
            onPressed: mode.backAction(onPrev),
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
              ? LoadingButton(
                  label: 'Next',
                  onPressed: mode.forwardAction(onNext),
                )
              : LoadingButton(
                  label: 'Check',
                  isLoading: feedback is Checking,
                  onPressed: checkEnabled ? onCheck : null,
                ),
        );
      case HomeworkMode(
        :final title,
        :final index,
        :final total,
        :final answered,
        :final marked,
      ):
        final label = 'Question ${index + 1} of $total';
        return QuestionFooter(
          leading: LoadingButton(
            label: 'Back',
            onPressed: mode.backAction(onPrev),
            variant: BookletButtonVariant.secondary,
          ),
          middle: layout == BookletLayout.compact
              ? _NavigatorFooterButton(
                  label: label,
                  onPressed: () => showHomeworkNavigatorSheet(
                    context,
                    title: title,
                    total: total,
                    index: index,
                    answered: answered,
                    marked: marked,
                    onJumpTo: onJumpTo,
                    onSubmit: onSubmit,
                  ),
                )
              : middle(label),
          primary: LoadingButton(
            label: 'Next',
            onPressed: mode.forwardAction(onNext),
          ),
        );
      case final QuizMode quiz:
        return _quizFooter(context, layout, quiz);
    }
  }

  Widget _quizFooter(
    BuildContext context,
    BookletLayout layout,
    QuizMode quiz,
  ) {
    final index = quiz.index;
    final total = quiz.total;
    final compact = layout == BookletLayout.compact;
    final scheme = Theme.of(context).colorScheme;
    final label = 'Question ${index + 1} of $total';
    final back = LoadingButton(
      label: 'Back',
      onPressed: quiz.backAction(onPrev),
      variant: BookletButtonVariant.secondary,
    );
    final primary = index == total - 1
        ? LoadingButton(
            label: 'Submit quiz',
            onPressed: _confirmSubmit(context, quiz),
          )
        : LoadingButton(label: 'Next', onPressed: quiz.forwardAction(onNext));
    void open() => _openNavigator(context, layout, quiz);

    if (layout != BookletLayout.expanded) {
      // Phone and medium widths: Back on the left, primary on the right.
      return QuestionFooter(
        phoneComposition: true,
        leading: back,
        middle: compact
            ? _NavigatorFooterButton(label: label, onPressed: open)
            : _inkNavigatorButton(scheme, label, open),
        primary: primary,
      );
    }
    return QuestionFooter(
      leading: null,
      middle: _inkNavigatorButton(scheme, label, open),
      primary: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: BookletSpace.s3,
        children: [back, primary],
      ),
    );
  }

  Widget _inkNavigatorButton(
    ColorScheme scheme,
    String label,
    VoidCallback onPressed,
  ) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: scheme.onSurface,
        foregroundColor: scheme.surface,
        minimumSize: const Size(0, BookletSize.touchTarget),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: BookletSpace.s1,
        children: [
          Flexible(child: Text(label, textAlign: TextAlign.center)),
          const Icon(AppIcons.collapse, size: BookletSize.iconStatus),
        ],
      ),
    );
  }

  /// Opens the phone sheet or the wide popover for a quiz. Cells jump only
  /// until time is up.
  void _openNavigator(
    BuildContext context,
    BookletLayout layout,
    QuizMode quiz,
  ) {
    final open = layout == BookletLayout.compact
        ? showNavigatorSheet
        : showNavigatorPopover;
    unawaited(
      open(
        context,
        title: '${quiz.title} questions',
        total: quiz.total,
        index: quiz.index,
        answered: quiz.answered,
        marked: quiz.marked,
        onJumpTo: quiz.isTimeUp ? null : onJumpTo,
        submitLabel: 'Submit quiz',
        onSubmitPressed: _confirmSubmit(context, quiz),
      ),
    );
  }

  /// Null when submitting is disabled; otherwise opens the confirm dialog.
  VoidCallback? _confirmSubmit(BuildContext context, QuizMode quiz) {
    final onConfirm = quiz.submitAction(onSubmit);
    if (onConfirm == null) return null;
    return () => unawaited(
      showSubmitConfirmDialog(
        context,
        title: 'Submit quiz?',
        body: 'After you submit, your answers are locked and marked.',
        confirmLabel: 'Submit quiz',
        total: quiz.total,
        answered: quiz.answered,
        onSubmit: onConfirm,
        onJumpTo: onJumpTo,
      ),
    );
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

/// Phone footer centre button: "Question i of n" and an up chevron. Wraps
/// rather than ellipsizing: the copy is never cut.
class _NavigatorFooterButton extends StatelessWidget {
  const _NavigatorFooterButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        padding: EdgeInsets.zero,
        minimumSize: const Size(0, BookletSize.touchTarget),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: BookletSpace.s1,
        children: [
          Flexible(child: Text(label, textAlign: TextAlign.center)),
          const Icon(AppIcons.collapse, size: BookletSize.iconStatus),
        ],
      ),
    );
  }
}
