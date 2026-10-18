import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/core/errors/supabase_error_mapper.dart';
import 'package:sat_east_client/core/supabase/rpc_caller.dart';
import 'package:sat_east_client/features/activation/data/models/activation_result_model.dart';
import 'package:sat_east_client/features/activation/domain/entities/activation_result.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _malformed = AppError(ErrorCodes.internal, 'malformed rpc payload');

class ActivationRemoteDataSource {
  ActivationRemoteDataSource(this._rpc);

  final RpcCaller _rpc;

  Future<Result<ActivationResult>> redeem(
    String code,
    DateTime testDate,
  ) async {
    try {
      final raw = await _rpc('redeem_activation_code', {
        'p_code': code,
        'p_target_test_date': _calendarDate(testDate),
      });
      if (raw is! Map) return const Failure(_malformed);
      final json = raw.cast<String, Object?>();
      if (json['ok'] == false) {
        final error = json['error'];
        if (error is String &&
            const {
              ErrorCodes.codeInvalid,
              ErrorCodes.codeUsed,
              ErrorCodes.alreadyEnrolled,
            }.contains(error)) {
          return Failure(AppError(error));
        }
        return const Failure(_malformed);
      }
      if (json['ok'] != true) return const Failure(_malformed);
      return Success(activationResultFromJson(json));
    } on PostgrestException catch (e) {
      return Failure(mapPostgrestException(e));
    } on FormatException {
      return const Failure(_malformed);
    } on Object catch (e) {
      return Failure(mapUnknownError(e));
    }
  }
}

// A test date is a calendar day; converting to UTC could change the chosen day.
String _calendarDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
