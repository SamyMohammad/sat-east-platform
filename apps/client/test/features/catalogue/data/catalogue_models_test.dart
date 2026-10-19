import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/features/catalogue/data/models/catalogue_course_model.dart';
import 'package:sat_east_client/features/catalogue/data/models/course_page_model.dart';

import '../catalogue_fixtures.dart';

void main() {
  test('PAY-01: catalogue maps the full RPC row', () {
    final course = catalogueCourseFromJson(coursePayload);
    expect(course.id, 'c1');
    expect(course.slug, 'sat-math');
    expect(course.title, 'SAT Math');
    expect(course.description, 'Build your math skills.');
    expect(course.topicCount, 3);
    expect(course.price?.currency, 'EGP');
    expect(course.price?.amountMinor, 240000);
  });
  test('PAY-01: nullable description and price stay nullable', () {
    final course = catalogueCourseFromJson({
      ...coursePayload,
      'description': null,
      'price': null,
    });
    expect(course.description, isNull);
    expect(course.price, isNull);
  });
  test('PAY-01: course page parses units without catalogue-only fields', () {
    final page = coursePageFromJson(pagePayload);
    expect(page.id, 'c1');
    expect(page.slug, 'sat-math');
    expect(page.title, 'SAT Math');
    expect(page.description, 'Build your math skills.');
    expect(page.price?.amountMinor, 240000);
    expect(page.units.map((u) => u.title), ['Algebra', 'Advanced math']);
    final topic = page.units.first.topics.first;
    expect(topic.slug, 'linear');
    expect(topic.title, 'Linear equations');
    expect(topic.isFreePreview, isTrue);
    expect(topic.subtopicCount, 4);
    expect(page.units.first.topics.last.isFreePreview, isFalse);
  });
  test('PAY-01: empty units are valid', () {
    final page = coursePageFromJson({...pagePayload, 'units': <Object?>[]});
    expect(page.units, isEmpty);
  });
  test('PAY-01: empty topics and null page price are valid', () {
    final page = coursePageFromJson({
      ...pagePayload,
      'price': null,
      'units': [
        {'title': 'Algebra', 'topics': <Object?>[]},
      ],
    });
    expect(page.units.single.topics, isEmpty);
    expect(page.price, isNull);
  });
  for (final row in [
    {...coursePayload, 'id': null},
    {...coursePayload, 'topic_count': -1},
    {
      ...coursePayload,
      'price': {'currency': 'EGP', 'amount_minor': '2400'},
    },
  ]) {
    test('PAY-01: malformed catalogue field is rejected: $row', () {
      expect(() => catalogueCourseFromJson(row), throwsFormatException);
    });
  }
}
