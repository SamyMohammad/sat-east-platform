import 'package:sat_east_client/core/attempts/save_outcome.dart';
import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/core/errors/supabase_error_mapper.dart';
import 'package:sat_east_client/core/supabase/rpc_caller.dart';
import 'package:sat_east_client/features/mock/data/models/mock_models.dart';
import 'package:sat_east_client/features/mock/domain/entities/mock_entities.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _malformed = AppError(ErrorCodes.internal, 'malformed rpc payload');

/// Reads the caller's own `mock_results` row by id (RLS `select own`); null
/// when there is no such row.
typedef MockResultReader =
    Future<Map<String, Object?>?> Function(String resultId);

/// [MockResultReader] over the Supabase client, wired in DI.
MockResultReader supabaseMockResultReader(SupabaseClient client) =>
    (resultId) => client
        .from('mock_results')
        .select(
          'id, route, raw_m1, raw_m2, est_low, est_high, domain_breakdown',
        )
        .eq('id', resultId)
        .maybeSingle();

class MockRemoteDataSource {
  MockRemoteDataSource(this._rpc, {required this.readResult});

  final RpcCaller _rpc;
  final MockResultReader readResult;

  Future<Result<MockHub>> hub(String courseId) =>
      _call('get_mock_hub', {'p_course_id': courseId}, mockHubFromJson);

  Future<Result<MockStage>> start(String courseId) =>
      _call('start_mock', {'p_course_id': courseId}, mockStageFromJson);

  Future<Result<MockStage>> session(String groupId) =>
      _call('get_mock_session', {'p_group_id': groupId}, mockStageFromJson);

  Future<Result<MockStage>> startModule2(String groupId) => _call(
    'start_mock_module2',
    {'p_group_id': groupId},
    mockStageFromJson,
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

  Future<Result<MockStage>> submit(String attemptId) => _call(
    'submit_attempt',
    {'p_attempt_id': attemptId},
    mockStageFromJson,
  );

  Future<Result<MockResult>> result(String resultId) async {
    try {
      final row = await readResult(resultId);
      if (row == null) return const Failure(_malformed);
      return Success(mockResultFromJson(row));
    } on PostgrestException catch (e) {
      return Failure(mapPostgrestException(e));
    } on FormatException {
      return const Failure(_malformed);
    } on Object catch (e) {
      return Failure(mapUnknownError(e));
    }
  }

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
