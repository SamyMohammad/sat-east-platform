import 'package:sat_east_client/core/errors/error_codes.dart';

abstract final class ActivationCopy {
  static const title = 'Enter activation code';
  static const codeLabel = 'Activation code';
  static const dateLabel = 'Test date';
  static const activate = 'Activate';
  static const missingCode = 'Enter your activation code.';
  static const invalidDate = 'Pick a test date in the next 18 months.';

  static String errorBody(String code) => switch (code) {
    ErrorCodes.codeInvalid => "That code isn't valid. Check it and try again.",
    ErrorCodes.codeUsed => 'That code has already been used.',
    ErrorCodes.alreadyEnrolled => "You're already enrolled in this course.",
    ErrorCodes.rateLimited => 'Too many tries. Wait a minute and try again.',
    ErrorCodes.invalidInput => invalidDate,
    ErrorCodes.network => 'Check your connection and try again.',
    _ => 'Something went wrong. Try again.',
  };
}
