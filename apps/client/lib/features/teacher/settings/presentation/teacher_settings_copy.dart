import 'package:sat_east_client/core/errors/error_codes.dart';

String teacherSettingsError(String code) => switch (code) {
  ErrorCodes.invalidInput => 'Some values are out of range. Nothing was saved.',
  ErrorCodes.forbidden => 'Only the teacher can change settings.',
  _ => "Couldn't save settings. Check your connection and try again.",
};

String deleteStudentError(String code) => switch (code) {
  ErrorCodes.invalidInput => 'Enter the email of the student to delete.',
  ErrorCodes.studentNotFound => 'No student has that email.',
  ErrorCodes.studentHasOrders =>
    'This student has payment records and cannot be deleted here.',
  ErrorCodes.forbidden =>
    'Only student accounts can be deleted, and only by a teacher.',
  ErrorCodes.rateLimited => 'Too many deletions. Try again later.',
  _ => "Couldn't delete the student. Check your connection and try again.",
};
