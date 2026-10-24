import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/core/errors/supabase_error_mapper.dart';
import 'package:sat_east_client/core/supabase/rpc_caller.dart';
import 'package:sat_east_client/features/teacher/review/data/models/review_models.dart';
import 'package:sat_east_client/features/teacher/review/domain/entities/review.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ReviewRemoteDataSource {
  ReviewRemoteDataSource(this._rpc);
  final RpcCaller _rpc;
  Future<Result<ReviewPage>> list(ReviewSection section, int page) => _call(
    'teacher_list_review_queue',
    {'p_section': section.value, 'p_page': page},
    reviewPageFromJson,
  );
  Future<Result<List<QuestionReport>>> reports(String id) => _call(
    'teacher_list_question_reports',
    {'p_question_id': id},
    reportsFromJson,
  );
  Future<Result<int>> resolve(String id, String outcome, String? note) => _call(
    'teacher_resolve_reports',
    {'p_question_id': id, 'p_outcome': outcome, 'p_note': note},
    closedFromJson,
  );
  Future<Result<ReviewCounts>> counts() =>
      _call('teacher_review_counts', {}, countsFromJson);
  Future<Result<T>> _call<T>(
    String fn,
    Map<String, Object?> params,
    T Function(Object?) parse,
  ) async {
    try {
      return Success(parse(await _rpc(fn, params)));
    } on PostgrestException catch (e) {
      return Failure(mapPostgrestException(e));
    } on FormatException {
      return const Failure(AppError(ErrorCodes.internal));
    } on Object catch (e) {
      return Failure(mapUnknownError(e));
    }
  }
}
