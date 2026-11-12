import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/core/errors/supabase_error_mapper.dart';
import 'package:sat_east_client/core/supabase/rpc_caller.dart';
import 'package:sat_east_client/features/teacher/mock/data/models/mock_models.dart';
import 'package:sat_east_client/features/teacher/mock/domain/entities/mock_entities.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TeacherMockRemoteDataSource {
  TeacherMockRemoteDataSource(this._rpc);
  final RpcCaller _rpc;

  Future<Result<MockOverview>> overview(String courseId) => _call(
    'teacher_mock_overview',
    {'p_course_id': courseId},
    mockOverviewFromJson,
  );

  Future<Result<AssembleResult>> assemble(String courseId, int setNo) => _call(
    'teacher_assemble_mock_form',
    {'p_course_id': courseId, 'p_set_no': setNo},
    assembleResultFromJson,
  );

  Future<Result<MockForm>> form(String courseId, int setNo, int formNo) =>
      _call(
        'teacher_get_mock_form',
        _formParams(courseId, setNo, formNo),
        mockFormFromJson,
      );

  Future<Result<List<MockCandidate>>> candidates(
    String courseId,
    int setNo,
    int formNo,
    String questionId,
  ) => _call('teacher_mock_swap_candidates', {
    ..._formParams(courseId, setNo, formNo),
    'p_question_id': questionId,
  }, mockCandidatesFromJson);

  Future<Result<void>> swap(
    String courseId,
    int setNo,
    int formNo,
    String oldId,
    String newId,
  ) => _call('teacher_swap_mock_question', {
    ..._formParams(courseId, setNo, formNo),
    'p_old_id': oldId,
    'p_new_id': newId,
  }, mockOkFromJson);

  Future<Result<void>> deleteDraft(String courseId, int setNo, int formNo) =>
      _call(
        'teacher_delete_mock_draft',
        _formParams(courseId, setNo, formNo),
        mockOkFromJson,
      );

  Future<Result<PublishResult>> publish(
    String courseId,
    int setNo,
    int formNo,
  ) => _call(
    'teacher_publish_mock_form',
    _formParams(courseId, setNo, formNo),
    publishResultFromJson,
  );

  Map<String, Object?> _formParams(String courseId, int setNo, int formNo) => {
    'p_course_id': courseId,
    'p_set_no': setNo,
    'p_form_no': formNo,
  };

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
