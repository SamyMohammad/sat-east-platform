import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/features/teacher/course_builder/data/models/course_builder_models.dart';

import '../builder_fixtures.dart';

void main() {
  test('C-1: parses full tree including drafts, flags and references', () {
    final tree = courseTreeFromJson(treeJson);
    expect(tree.courseId, 'c1');
    expect(tree.code, 'SAT');
    expect(tree.units.first.topics.first.isPublished, isFalse);
    expect(tree.units.first.inUse, isTrue);
    final topic = tree.units.first.topics.last;
    expect(topic.isFreePreview, isTrue);
    expect(topic.subtopicCount, 0);
    expect(topic.subtopics, isEmpty);
    expect(
      tree.units.first.topics.first.subtopics.last.title,
      'Algebra',
    );
  });
  test('C-1: parses unpublished teacher course', () {
    final course = teacherCourseFromJson(coursesJson.last);
    expect(course.id, 'c2');
    expect(course.slug, 'est');
    expect(course.isPublished, isFalse);
  });
  for (final invalid in <Map<String, Object?>>[
    {},
    {...treeJson, 'course': null},
    {...treeJson, 'units': null},
    {
      ...treeJson,
      'units': [
        {'id': 12},
      ],
    },
  ]) {
    test('C-1: malformed tree throws FormatException $invalid', () {
      expect(() => courseTreeFromJson(invalid), throwsFormatException);
    });
  }
}
