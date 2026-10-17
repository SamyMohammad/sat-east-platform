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

  static String summaryBody(int correctFirstTry, int total) =>
      'You got $correctFirstTry of $total right on the first try.';

  static String errorBody(String code) => code == ErrorCodes.network
      ? LearningCopy.networkBody
      : LearningCopy.genericBody;
}
