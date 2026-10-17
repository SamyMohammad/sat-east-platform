import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/core/errors/supabase_error_mapper.dart';
import 'package:sat_east_client/core/supabase/rpc_caller.dart';

import 'package:sat_east_client/features/practice/data/models/practice_model.dart';
import 'package:sat_east_client/features/practice/domain/entities/practice.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _malformed = AppError(ErrorCodes.internal, 'malformed rpc payload');

class PracticeRemoteDataSource {
  PracticeRemoteDataSource(this._rpc);

  final RpcCaller _rpc;

  Future<Result<PracticeSet>> start(String topicId) async {
    try {
      final raw = await _rpc('get_practice_questions', {'p_topic_id': topicId});
      if (raw is! Map) return const Failure(_malformed);
      return Success(practiceSetFromJson(raw.cast<String, Object?>()));
    } on PostgrestException catch (e) {
      return Failure(mapPostgrestException(e));
    } on FormatException {
      return const Failure(_malformed);
    } on Object catch (e) {
      return Failure(mapUnknownError(e));
    }
  }

  Future<Result<CheckResult>> check({
    required String attemptId,
    required String questionId,
    required String answer,
    required int timeMs,
  }) async {
    try {
      final raw = await _rpc('check_practice_answer', {
        'p_attempt_id': attemptId,
        'p_question_id': questionId,
        'p_answer': answer,
        'p_time_ms': timeMs,
      });
      if (raw is! Map) return const Failure(_malformed);
      return Success(checkResultFromJson(raw.cast<String, Object?>()));
    } on PostgrestException catch (e) {
      return Failure(mapPostgrestException(e));
    } on FormatException {
      return const Failure(_malformed);
    } on Object catch (e) {
      return Failure(mapUnknownError(e));
    }
  }
}
