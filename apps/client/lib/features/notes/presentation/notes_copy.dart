import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/presentation/learning_copy.dart';

String notesErrorCopy(String code) => switch (code) {
  ErrorCodes.topicLocked => LearningCopy.lockedBody,
  ErrorCodes.notEnrolled => LearningCopy.notEnrolledBody,
  ErrorCodes.accessExpired => LearningCopy.expiredBody,
  ErrorCodes.forbidden => "You don't have access to these notes.",
  ErrorCodes.invalidInput => "These notes aren't available.",
  _ => "Couldn't open the notes. Check your connection and try again.",
};
