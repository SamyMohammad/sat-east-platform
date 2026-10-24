import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/presentation/learning_copy.dart';

abstract final class PracticeCopy {
  static const title = 'Practice';
  static const summaryTitle = 'Practice complete';
  static const moreButton = 'Practice more';
  static const backButton = 'Back to course';
  static const String lockedBody = LearningCopy.lockedBody;
  static const emptyBody = 'No practice questions yet.';
  static const errorTitle = "Couldn't load practice";
  static const checkError = "Couldn't check your answer. Try again.";

  static const Map<String, String> reportReasons = {
    'answer_key': 'The answer key is wrong',
    'typo': 'Typo or unclear wording',
    'math_display': "Math doesn't display",
    'other': 'Other',
  };
  static const reportThanks = 'Thanks \u2014 your teacher will review it.';
  static String reportError(String code) => switch (code) {
    ErrorCodes.rateLimited => 'Too many reports. Try again in a minute.',
    ErrorCodes.notAuthenticated => 'Sign in to report a problem.',
    ErrorCodes.invalidInput =>
      "Couldn't send this report. Reload and try again.",
    ErrorCodes.forbidden => "You can't report this question.",
    ErrorCodes.network => LearningCopy.networkBody,
    _ => "Couldn't send your report. Try again.",
  };

  static String summaryBody(int correctFirstTry, int total) =>
      'You got $correctFirstTry of $total right on the first try.';

  static String errorBody(String code) => code == ErrorCodes.notesNeeded
      ? 'Open the notes first.'
      : code == ErrorCodes.network
      ? LearningCopy.networkBody
      : LearningCopy.genericBody;
}
