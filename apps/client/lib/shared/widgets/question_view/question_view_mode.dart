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
