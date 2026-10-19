import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/teacher/course_builder/data/datasources/course_builder_remote_data_source.dart';
import 'package:sat_east_client/features/teacher/course_builder/domain/entities/course_tree.dart';
import 'package:sat_east_client/features/teacher/course_builder/domain/entities/node_kind.dart';
import 'package:sat_east_client/features/teacher/course_builder/domain/repositories/course_builder_repository.dart';

class CourseBuilderRepositoryImpl implements CourseBuilderRepository {
  CourseBuilderRepositoryImpl(this._remote);
  final CourseBuilderRemoteDataSource _remote;

  @override
  Future<Result<List<TeacherCourse>>> listCourses() => _remote.listCourses();

  @override
  Future<Result<CourseTree>> getTree(String courseId) =>
      _remote.getTree(courseId);

  @override
  Future<Result<String>> upsertUnit({
    required String courseId,
    required String title,
    String? id,
  }) => _remote.upsertUnit(id: id, courseId: courseId, title: title);

  @override
  Future<Result<String>> upsertTopic({
    required String unitId,
    required String title,
    String? id,
  }) => _remote.upsertTopic(id: id, unitId: unitId, title: title);

  @override
  Future<Result<String>> upsertSubtopic({
    required String topicId,
    required String title,
    String? id,
  }) => _remote.upsertSubtopic(id: id, topicId: topicId, title: title);

  @override
  Future<Result<void>> reorder(
    NodeKind kind,
    String parentId,
    List<String> ids,
  ) => _remote.reorder(kind, parentId, ids);

  @override
  Future<Result<void>> delete(NodeKind kind, String id) =>
      _remote.delete(kind, id);

  @override
  Future<Result<TopicFlags>> setFlags(
    String id, {
    bool? isPublished,
    bool? isFreePreview,
  }) => _remote.setFlags(
    id,
    isPublished: isPublished,
    isFreePreview: isFreePreview,
  );
}
