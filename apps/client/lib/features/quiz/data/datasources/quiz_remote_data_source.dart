import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/core/errors/supabase_error_mapper.dart';
import 'package:sat_east_client/core/supabase/rpc_caller.dart';
import 'package:sat_east_client/features/quiz/data/models/quiz_model.dart';
import 'package:sat_east_client/features/quiz/domain/entities/quiz.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _malformed = AppError(ErrorCodes.internal, 'malformed rpc payload');

class QuizRemoteDataSource {
  QuizRemoteDataSource(this._rpc);

  final RpcCaller _rpc;

  Future<Result<QuizSession>> start(String topicId) => _call(
    'start_quiz',
    {'p_topic_id': topicId},
    quizSessionFromJson,
  );

  Future<Result<SaveOutcome>> save({
    required String attemptId,
    required String questionId,
    required int timeMs,
    required bool marked,
    required List<String> eliminated,
    required int clientSeq,
    String? answer,
  }) => _call('save_answer', {
    'p_attempt_id': attemptId,
    'p_question_id': questionId,
    'p_answer': answer,
    'p_time_ms': timeMs,
    'p_marked': marked,
    'p_eliminated': eliminated,
    'p_client_seq': clientSeq,
  }, saveOutcomeFromJson);

  Future<Result<QuizReport>> submit(String attemptId) => _call(
    'submit_attempt',
    {'p_attempt_id': attemptId},
    (json) => quizReportFromJson(json, attemptId),
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
