import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/core/errors/supabase_error_mapper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HomeSettingsRemoteDataSource {
  HomeSettingsRemoteDataSource({
    required this._readWarnDays,
  });

  final Future<Map<String, dynamic>> Function() _readWarnDays;

  Future<Result<int>> expiryWarnDays() async {
    try {
      final row = await _readWarnDays();
      final value = row['value'];
      if (value is! int) {
        return const Failure(AppError(ErrorCodes.invalidInput));
      }
      return Success(value);
    } on PostgrestException catch (error) {
      return Failure(mapPostgrestException(error));
    } on Object catch (error) {
      return Failure(mapUnknownError(error));
    }
  }
}
