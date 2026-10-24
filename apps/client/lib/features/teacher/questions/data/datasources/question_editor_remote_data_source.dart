import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/core/errors/supabase_error_mapper.dart';
import 'package:sat_east_client/core/supabase/rpc_caller.dart';
import 'package:sat_east_client/features/teacher/questions/data/models/question_draft_model.dart';
import 'package:sat_east_client/features/teacher/questions/domain/entities/question_draft.dart';
import 'package:sat_east_client/features/teacher/questions/domain/entities/question_save_result.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class QuestionEditorRemoteDataSource {
  QuestionEditorRemoteDataSource(this._rpc);
  final RpcCaller _rpc;
  Future<Result<QuestionDraft>> get(String id) =>
      _call('teacher_get_question', {'p_id': id}, questionDraftFromJson);
  Future<Result<QuestionSaveResult>> save(QuestionDraft draft) =>
      _call('teacher_save_question', {
        'p_id': draft.id,
        'p_row': questionDraftToJson(draft),
        'p_expected_version': draft.version,
      }, questionSaveResultFromJson);
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
