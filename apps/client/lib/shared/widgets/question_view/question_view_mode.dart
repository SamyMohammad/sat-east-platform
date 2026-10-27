import 'package:flutter/foundation.dart' show VoidCallback;

import 'package:sat_east_client/shared/widgets/question_view/practice_feedback.dart';
import 'package:sat_east_client/shared/widgets/question_view/rep_outcome.dart';

enum SaveStatus { saving, saved, offline, failed }

sealed class QuestionViewMode {
  const QuestionViewMode();
}

final class PracticeMode extends QuestionViewMode {
  const PracticeMode({
    required this.feedback,
    required this.rep,
    required this.repTarget,
    this.noteAuthor,
    this.outcomes = const [],
  });

  final PracticeFeedback feedback;
  final int rep;
  final int repTarget;

  /// Outcome i belongs to rep i. Shorter than the reps done when a set was
  /// resumed: those earlier reps are drawn as plain progress.
  final List<RepOutcome> outcomes;
  final String? noteAuthor;
}

final class HomeworkMode extends QuestionViewMode {
  const HomeworkMode({
    required this.title,
    required this.index,
    required this.total,
    required this.saveStatus,
    this.answered = const {},
    this.marked = const {},
  });

  /// e.g. "Homework 4.2".
  final String title;

  /// 0-based.
  final int index;
  final int total;
  final SaveStatus saveStatus;
  final Set<int> answered;
  final Set<int> marked;
}

final class QuizMode extends QuestionViewMode {
  const QuizMode({
    required this.title,
    required this.index,
    required this.total,
    required this.remaining,
    required this.timeBudget,
    required this.warnAt,
    this.timerHidden = false,
    this.answered = const {},
    this.marked = const {},
  });

  /// e.g. "Quiz 4.2".
  final String title;

  /// 0-based.
  final int index;
  final int total;
  final Duration remaining;
  final Duration timeBudget;

  /// The remaining time at which the warning banner appears (from settings).
  final Duration warnAt;
  final bool timerHidden;
  final Set<int> answered;
  final Set<int> marked;
}

/// The enabled-state rules shared by the footer and the keyboard shortcuts,
/// so the two cannot drift apart (ruling R8).
extension QuestionViewModeGating on QuestionViewMode {
  /// A quiz whose clock has run out accepts no more input.
  bool get isTimeUp => switch (this) {
    QuizMode(:final remaining) => remaining <= Duration.zero,
    PracticeMode() || HomeworkMode() => false,
  };

  /// A quiz inside its warning window.
  bool get isWarning => switch (this) {
    QuizMode(:final remaining, :final warnAt) => remaining <= warnAt,
    PracticeMode() || HomeworkMode() => false,
  };

  /// The warning banner shows inside the warning window, but not once time
  /// is up.
  bool get showsWarningBanner => isWarning && !isTimeUp;

  /// Tiles accept select / eliminate / restore only in homework, `Idle` and
  /// `FirstMiss`, and in a quiz until time is up.
  bool get choicesInteractive => switch (this) {
    HomeworkMode() => true,
    QuizMode() => !isTimeUp,
    PracticeMode(:final feedback) => feedback is Idle || feedback is FirstMiss,
  };

  /// [onNext] when the footer's forward action is enabled, otherwise null.
  VoidCallback? forwardAction(VoidCallback? onNext) => switch (this) {
    PracticeMode(:final feedback) =>
      feedback is Correct || feedback is Revealed ? onNext : null,
    HomeworkMode(:final index, :final total) =>
      index < total - 1 ? onNext : null,
    QuizMode(:final index, :final total) =>
      !isTimeUp && index < total - 1 ? onNext : null,
  };

  /// [onPrev] when the footer's Back action is enabled, otherwise null.
  VoidCallback? backAction(VoidCallback? onPrev) => switch (this) {
    PracticeMode() => onPrev,
    HomeworkMode(:final index) => index > 0 ? onPrev : null,
    QuizMode(:final index) => !isTimeUp && index > 0 ? onPrev : null,
  };

  /// [onMark] when marking for review is enabled, otherwise null.
  VoidCallback? markAction(VoidCallback? onMark) => switch (this) {
    QuizMode() => isTimeUp ? null : onMark,
    PracticeMode() || HomeworkMode() => onMark,
  };

  /// [onSubmit] when submitting is enabled, otherwise null.
  VoidCallback? submitAction(VoidCallback? onSubmit) => switch (this) {
    HomeworkMode() => onSubmit,
    QuizMode() => isTimeUp ? null : onSubmit,
    PracticeMode() => null,
  };
}
