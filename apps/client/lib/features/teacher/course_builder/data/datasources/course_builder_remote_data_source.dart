import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/core/errors/supabase_error_mapper.dart';
import 'package:sat_east_client/core/supabase/rpc_caller.dart';
import 'package:sat_east_client/features/teacher/course_builder/data/models/course_builder_models.dart';
import 'package:sat_east_client/features/teacher/course_builder/domain/entities/course_tree.dart';
import 'package:sat_east_client/features/teacher/course_builder/domain/entities/node_kind.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CourseBuilderRemoteDataSource {
  CourseBuilderRemoteDataSource(this._rpc);
  final RpcCaller _rpc;

  Future<Result<List<TeacherCourse>>> listCourses() => _call(
    'teacher_list_courses',
    {},
    (raw) => builderJsonList(raw).map(teacherCourseFromJson).toList(),
  );

  Future<Result<CourseTree>> getTree(String courseId) => _call(
    'teacher_get_course_tree',
    {'p_course_id': courseId},
    (raw) => courseTreeFromJson(builderJsonObject(raw)),
  );

  Future<Result<String>> upsertUnit({
    required String courseId,
    required String title,
    String? id,
  }) => _call('teacher_upsert_unit', {
    'p_id': id,
    'p_course_id': courseId,
    'p_title': title,
  }, (raw) => builderIdFromJson(builderJsonObject(raw)));

  Future<Result<String>> upsertTopic({
    required String unitId,
    required String title,
    String? id,
  }) => _call('teacher_upsert_topic', {
    'p_id': id,
    'p_unit_id': unitId,
    'p_title': title,
  }, (raw) => builderIdFromJson(builderJsonObject(raw)));

  Future<Result<String>> upsertSubtopic({
    required String topicId,
    required String title,
    String? id,
  }) => _call('teacher_upsert_subtopic', {
    'p_id': id,
    'p_topic_id': topicId,
    'p_title': title,
  }, (raw) => builderIdFromJson(builderJsonObject(raw)));

  Future<Result<void>> reorder(
    NodeKind kind,
    String parentId,
    List<String> ids,
  ) => _call('teacher_reorder', {
    'p_kind': kind.name,
    'p_parent_id': parentId,
    'p_ids': ids,
  }, (raw) => builderOkFromJson(builderJsonObject(raw)));

  Future<Result<void>> delete(NodeKind kind, String id) => _call(
    'teacher_delete_node',
    {'p_kind': kind.name, 'p_id': id},
    (raw) => builderOkFromJson(builderJsonObject(raw)),
  );

  Future<Result<TopicFlags>> setFlags(
    String id, {
    bool? isPublished,
    bool? isFreePreview,
  }) => _call('teacher_set_topic_flags', {
    'p_id': id,
    'p_is_published': isPublished,
    'p_is_free_preview': isFreePreview,
  }, (raw) => topicFlagsFromJson(builderJsonObject(raw)));

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
      return const Failure(
        AppError(ErrorCodes.internal, 'malformed rpc payload'),
      );
    } on Object catch (e) {
      return Failure(mapUnknownError(e));
    }
  }
}
