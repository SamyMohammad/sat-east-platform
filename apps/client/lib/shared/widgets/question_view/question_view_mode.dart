import 'package:flutter/foundation.dart' show VoidCallback;

import 'package:sat_east_client/shared/widgets/question_view/practice_feedback.dart';

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
  });

  final PracticeFeedback feedback;
  final int rep;
  final int repTarget;
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

/// The enabled-state rules shared by the footer and the keyboard shortcuts,
/// so the two cannot drift apart (ruling R8).
extension QuestionViewModeGating on QuestionViewMode {
  /// Tiles accept select / eliminate / restore only in homework, `Idle` and
  /// `FirstMiss`.
  bool get choicesInteractive => switch (this) {
    HomeworkMode() => true,
    PracticeMode(:final feedback) => feedback is Idle || feedback is FirstMiss,
  };

  /// [onNext] when the footer's forward action is enabled, otherwise null.
  VoidCallback? forwardAction(VoidCallback? onNext) => switch (this) {
    PracticeMode(:final feedback) =>
      feedback is Correct || feedback is Revealed ? onNext : null,
    HomeworkMode(:final index, :final total) =>
      index < total - 1 ? onNext : null,
  };

  /// [onPrev] when the footer's Back action is enabled, otherwise null.
  VoidCallback? backAction(VoidCallback? onPrev) => switch (this) {
    PracticeMode() => onPrev,
    HomeworkMode(:final index) => index > 0 ? onPrev : null,
  };
}
