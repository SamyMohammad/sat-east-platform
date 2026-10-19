import 'package:sat_east_client/core/errors/error_codes.dart';

String teacherSettingsError(String code) => switch (code) {
  ErrorCodes.invalidInput => 'Some values are out of range. Nothing was saved.',
  ErrorCodes.forbidden => 'Only the teacher can change settings.',
  _ => "Couldn't save settings. Check your connection and try again.",
};
