import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/presentation/format_percentage.dart';
import 'package:sat_east_client/core/presentation/learning_copy.dart';

abstract final class AttemptReviewCopy {
  static const title = 'Attempt report';
  static const retry = 'Retry';
  static const back = 'Back';
  static const myAnswer = 'My answer';
  static const correctAnswer = 'Correct answer';
  static const explanation = 'Explanation';
  static const unanswered = 'Unanswered';
  static const correct = 'Correct';
  static const incorrect = 'Incorrect';
  static const hidden = 'Pass the topic quiz to see keys and explanations.';
  static const empty = 'No questions to review.';
  static String question(int index) => 'Question ${index + 1}';
  static String score(int raw, int total, double pct) =>
      '$raw / $total \u00b7 ${formatPercentage(pct)}';

  static String errorBody(String code) => switch (code) {
    ErrorCodes.attemptNotSubmitted =>
      'Submit this attempt before viewing its report.',
    ErrorCodes.forbidden => 'This report is not available to your account.',
    ErrorCodes.network => LearningCopy.networkBody,
    _ => LearningCopy.genericBody,
  };
}
