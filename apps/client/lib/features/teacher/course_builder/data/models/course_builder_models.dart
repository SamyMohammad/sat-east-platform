import 'package:sat_east_client/features/teacher/course_builder/domain/entities/course_tree.dart';

TeacherCourse teacherCourseFromJson(Map<String, Object?> json) => TeacherCourse(
  id: _string(json, 'id'),
  code: _string(json, 'code'),
  title: _string(json, 'title'),
  slug: _string(json, 'slug'),
  isPublished: _bool(json, 'is_published'),
);

CourseTree courseTreeFromJson(Map<String, Object?> json) {
  final course = builderJsonObject(json['course']);
  return CourseTree(
    courseId: _string(course, 'id'),
    title: _string(course, 'title'),
    code: _string(course, 'code'),
    units: builderJsonList(json['units'])
        .map(
          (u) => BuilderUnit(
            id: _string(u, 'id'),
            title: _string(u, 'title'),
            sort: _int(u, 'sort'),
            inUse: _bool(u, 'in_use'),
            topics: builderJsonList(u['topics']).map(_topic).toList(),
          ),
        )
        .toList(),
  );
}

BuilderTopic _topic(Map<String, Object?> t) => BuilderTopic(
  id: _string(t, 'id'),
  title: _string(t, 'title'),
  slug: _string(t, 'slug'),
  sort: _int(t, 'sort'),
  isPublished: _bool(t, 'is_published'),
  isFreePreview: _bool(t, 'is_free_preview'),
  subtopicCount: _int(t, 'subtopic_count'),
  inUse: _bool(t, 'in_use'),
  subtopics: builderJsonList(t['subtopics'])
      .map(
        (s) => BuilderSubtopic(
          id: _string(s, 'id'),
          title: _string(s, 'title'),
          sort: _int(s, 'sort'),
          inUse: _bool(s, 'in_use'),
        ),
      )
      .toList(),
);

TopicFlags topicFlagsFromJson(Map<String, Object?> json) => (
  isPublished: _bool(json, 'is_published'),
  isFreePreview: _bool(json, 'is_free_preview'),
);

String builderIdFromJson(Map<String, Object?> json) => _string(json, 'id');
void builderOkFromJson(Map<String, Object?> json) {
  if (json['ok'] != true) {
    throw const FormatException('ok');
  }
}

Map<String, Object?> builderJsonObject(Object? value) {
  if (value is! Map<String, Object?>) {
    throw const FormatException('object');
  }
  return value;
}

List<Map<String, Object?>> builderJsonList(Object? value) {
  if (value is! List<Object?>) {
    throw const FormatException('list');
  }
  return value.map(builderJsonObject).toList();
}

String _string(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String || value.isEmpty) {
    throw FormatException(key);
  }
  return value;
}

bool _bool(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! bool) {
    throw FormatException(key);
  }
  return value;
}

int _int(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! int) {
    throw FormatException(key);
  }
  return value;
}
