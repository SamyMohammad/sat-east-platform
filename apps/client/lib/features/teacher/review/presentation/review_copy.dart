import 'package:sat_east_client/core/errors/error_codes.dart';

String reviewReasonLabel(String reason) => switch (reason) {
  'answer_key' => 'Answer key is wrong',
  'typo' => 'Typo or unclear wording',
  'math_display' => "Math doesn't display",
  _ => 'Other',
};
String reviewErrorCopy(String code) => switch (code) {
  ErrorCodes.forbidden => 'Only the teacher can view the review queue.',
  ErrorCodes.notAuthenticated => 'Sign in again to review questions.',
  ErrorCodes.invalidInput => "That change wasn't saved. Reload and try again.",
  _ => "Couldn't load or save reports. Check your connection and try again.",
};
