import 'dart:convert';

import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';

Result<List<Object?>> parseImportFile(String text) {
  try {
    final decoded = jsonDecode(text);
    if (decoded is List<Object?>) return Success(decoded);
  } on FormatException {
    return const Failure(AppError(ErrorCodes.invalidInput));
  }
  return const Failure(AppError(ErrorCodes.invalidInput));
}
