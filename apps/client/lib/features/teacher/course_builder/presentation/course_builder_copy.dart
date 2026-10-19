import 'package:sat_east_client/core/errors/error_codes.dart';

String courseBuilderError(String code) => switch (code) {
  ErrorCodes.inUse => "This item is in use and can't be deleted.",
  ErrorCodes.forbidden => 'Only the teacher can change the course.',
  ErrorCodes.invalidInput => "That change wasn't saved. Reload and try again.",
  _ => "Couldn't save. Check your connection and try again.",
};
