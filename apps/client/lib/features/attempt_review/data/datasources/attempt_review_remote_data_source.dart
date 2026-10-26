import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/core/errors/supabase_error_mapper.dart';
import 'package:sat_east_client/core/supabase/rpc_caller.dart';
import 'package:sat_east_client/features/attempt_review/data/models/attempt_review_model.dart';
import 'package:sat_east_client/features/attempt_review/domain/entities/attempt_review.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _malformed = AppError(ErrorCodes.internal, 'malformed rpc payload');

class AttemptReviewRemoteDataSource {
  AttemptReviewRemoteDataSource(this._rpc);

  final RpcCaller _rpc;

  Future<Result<AttemptReview>> load(String attemptId) => _call(
    'get_attempt_review',
    {'p_attempt_id': attemptId},
    attemptReviewFromJson,
  );

  Future<Result<T>> _call<T>(
    String function,
    Map<String, Object?> params,
    T Function(Map<String, Object?>) parse,
  ) async {
    try {
      final raw = await _rpc(function, params);
      if (raw is! Map) return const Failure(_malformed);
      return Success(parse(raw.cast<String, Object?>()));
    } on PostgrestException catch (e) {
      return Failure(mapPostgrestException(e));
    } on FormatException {
      return const Failure(_malformed);
    } on Object catch (e) {
      return Failure(mapUnknownError(e));
    }
  }
}
