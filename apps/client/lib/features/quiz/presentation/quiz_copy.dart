import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/presentation/learning_copy.dart';

abstract final class QuizCopy {
  static const title = 'Quiz';
  static const passed = 'Quiz passed';
  static const notPassed = 'Quiz not passed';
  static const nextTopic = 'Next topic';
  static const backToCourse = 'Back to course';
  static const notSaved = 'Not saved \u2014 retrying';
  static const saveStopped = 'Not saved \u2014 return to the topic';
  static const submitting = 'Submitting quiz\u2026';
  static const submitError = "Couldn't submit your quiz. Try again.";
  static const retrySubmit = 'Retry submit';
  static const retakeUnavailable =
      'Return to the topic to check when you can retake the quiz.';

  static String question(int index) => 'Question ${index + 1}';

  static String score(int raw, int total, double pct) {
    final value = pct == pct.truncateToDouble() ? pct.toInt() : pct;
    return '$raw of $total correct \u00b7 $value%';
  }

  static String passMark(int mark) => 'Pass mark $mark%';

  static String resultDetail(int raw, int total, int mark) =>
      '$raw of $total correct · ${passMark(mark)}';

  static String retake(String localTime) =>
      'You can retake it after $localTime.';

  static String errorTitle(String code) => switch (code) {
    ErrorCodes.notEnrolled => LearningCopy.notEnrolledTitle,
    ErrorCodes.accessExpired => LearningCopy.expiredTitle,
    _ => title,
  };

  static String errorBody(String code) => switch (code) {
    ErrorCodes.homeworkNeeded => 'Submit the homework first.',
    ErrorCodes.practiceNeeded =>
      'Complete more practice before starting this quiz.',
    ErrorCodes.cooldownActive =>
      'You can retake this quiz after the cooldown ends.',
    ErrorCodes.topicLocked => LearningCopy.lockedBody,
    ErrorCodes.accessExpired => LearningCopy.expiredBody,
    ErrorCodes.notEnrolled => LearningCopy.notEnrolledBody,
    ErrorCodes.poolExhausted => 'No quiz questions yet.',
    ErrorCodes.network => LearningCopy.networkBody,
    _ => LearningCopy.genericBody,
  };
}
