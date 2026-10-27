import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/teacher/course_builder/domain/entities/course_tree.dart';
import 'package:sat_east_client/features/teacher/course_builder/domain/entities/node_kind.dart';

abstract interface class CourseBuilderRepository {
  Future<Result<List<TeacherCourse>>> listCourses();
  Future<Result<CourseTree>> getTree(String courseId);
  Future<Result<String>> upsertUnit({
    required String courseId,
    required String title,
    String? id,
  });
  Future<Result<String>> upsertTopic({
    required String unitId,
    required String title,
    String? id,
  });
  Future<Result<String>> upsertSubtopic({
    required String topicId,
    required String title,
    String? id,
  });
  Future<Result<void>> reorder(
    NodeKind kind,
    String parentId,
    List<String> ids,
  );
  Future<Result<void>> delete(NodeKind kind, String id);
  Future<Result<TopicFlags>> setFlags(
    String id, {
    bool? isPublished,
    bool? isFreePreview,
  });
}
