import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/presentation/learning_copy.dart';

abstract final class HomeworkCopy {
  static const title = 'Homework';
  static const start = 'Start homework';
  static const viewReport = 'View report';
  static const practiceNeeded = 'Complete the practice first.';
  static String continueHomework(int answered, int total) =>
      'Continue homework ($answered / $total answered)';
  static String submitted(double score) {
    final value = score == score.truncateToDouble() ? score.toInt() : score;
    return 'Submitted \u00b7 $value%';
  }

  static const submitting = 'Submitting homework\u2026';
  static const retry = 'Retry';
  static const submitFailed = "Couldn't submit your homework.";
  static String question(int index) => 'Question ${index + 1}';
  static String errorBody(String code) => switch (code) {
    ErrorCodes.practiceNeeded => 'Complete the practice first.',
    ErrorCodes.videoNeeded => 'Watch the video first.',
    ErrorCodes.notesNeeded => 'Open the notes first.',
    ErrorCodes.topicLocked => LearningCopy.lockedBody,
    ErrorCodes.notEnrolled => LearningCopy.notEnrolledBody,
    ErrorCodes.accessExpired => LearningCopy.expiredBody,
    ErrorCodes.poolExhausted => 'No homework questions yet.',
    ErrorCodes.attemptClosed => 'This homework has already been submitted.',
    ErrorCodes.invalidInput => 'Return to the topic to check your homework.',
    ErrorCodes.network => LearningCopy.networkBody,
    _ => LearningCopy.genericBody,
  };
}
