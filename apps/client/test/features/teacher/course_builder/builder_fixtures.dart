import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/teacher/course_builder/data/models/course_builder_models.dart';
import 'package:sat_east_client/features/teacher/course_builder/domain/entities/course_tree.dart';
import 'package:sat_east_client/features/teacher/course_builder/domain/entities/node_kind.dart';
import 'package:sat_east_client/features/teacher/course_builder/domain/repositories/course_builder_repository.dart';

const List<Map<String, Object?>> coursesJson = [
  {
    'id': 'c1',
    'code': 'SAT',
    'title': 'SAT Math',
    'slug': 'sat',
    'is_published': true,
  },
  {
    'id': 'c2',
    'code': 'EST',
    'title': 'EST Math',
    'slug': 'est',
    'is_published': false,
  },
];
const treeJson = <String, Object?>{
  'course': {'id': 'c1', 'title': 'SAT Math', 'code': 'SAT'},
  'units': [
    {
      'id': 'u1',
      'title': 'Algebra',
      'sort': 1,
      'in_use': true,
      'topics': [
        {
          'id': 't1',
          'title': 'Linear equations',
          'slug': 'linear',
          'sort': 1,
          'is_published': false,
          'is_free_preview': false,
          'subtopic_count': 2,
          'in_use': true,
          'subtopics': [
            {'id': 's1', 'title': 'Basics', 'sort': 1, 'in_use': false},
            {
              'id': 's2',
              'title': '\u062c\u0628\u0631',
              'sort': 2,
              'in_use': false,
            },
          ],
        },
        {
          'id': 't2',
          'title': 'Quadratics',
          'slug': 'quadratics',
          'sort': 2,
          'is_published': true,
          'is_free_preview': true,
          'subtopic_count': 0,
          'in_use': false,
          'subtopics': <Map<String, Object?>>[],
        },
      ],
    },
    {
      'id': 'u2',
      'title': 'Geometry',
      'sort': 2,
      'in_use': false,
      'topics': <Map<String, Object?>>[],
    },
  ],
};
final CourseTree builderTree = courseTreeFromJson(treeJson);
final List<TeacherCourse> builderCourses = coursesJson
    .map(teacherCourseFromJson)
    .toList();

class FakeBuilderRepository implements CourseBuilderRepository {
  Result<List<TeacherCourse>> courses = Success(builderCourses);
  Result<CourseTree> tree = Success(builderTree);
  Result<String> write = const Success('new-id');
  Result<void> mutation = const Success(null);
  Result<TopicFlags> flags = const Success((
    isPublished: true,
    isFreePreview: false,
  ));
  Future<Result<void>>? pending;
  Future<Result<CourseTree>>? pendingTree;
  void Function()? onTree;
  final calls = <(String, Map<String, Object?>)>[];

  @override
  Future<Result<List<TeacherCourse>>> listCourses() async {
    calls.add(('list', {}));
    return courses;
  }

  @override
  Future<Result<CourseTree>> getTree(String courseId) {
    calls.add(('tree', {'courseId': courseId}));
    onTree?.call();
    return pendingTree ?? Future.value(tree);
  }

  @override
  Future<Result<String>> upsertUnit({
    required String courseId,
    required String title,
    String? id,
  }) async {
    calls.add(('unit', {'id': id, 'parent': courseId, 'title': title}));
    return write;
  }

  @override
  Future<Result<String>> upsertTopic({
    required String unitId,
    required String title,
    String? id,
  }) async {
    calls.add(('topic', {'id': id, 'parent': unitId, 'title': title}));
    return write;
  }

  @override
  Future<Result<String>> upsertSubtopic({
    required String topicId,
    required String title,
    String? id,
  }) async {
    calls.add(('subtopic', {'id': id, 'parent': topicId, 'title': title}));
    return write;
  }

  @override
  Future<Result<void>> reorder(
    NodeKind kind,
    String parentId,
    List<String> ids,
  ) {
    calls.add(('reorder', {'kind': kind.name, 'parent': parentId, 'ids': ids}));
    return pending ?? Future.value(mutation);
  }

  @override
  Future<Result<void>> delete(NodeKind kind, String id) async {
    calls.add(('delete', {'kind': kind.name, 'id': id}));
    return mutation;
  }

  @override
  Future<Result<TopicFlags>> setFlags(
    String id, {
    bool? isPublished,
    bool? isFreePreview,
  }) async {
    calls.add((
      'flags',
      {'id': id, 'published': isPublished, 'preview': isFreePreview},
    ));
    return flags;
  }
}
