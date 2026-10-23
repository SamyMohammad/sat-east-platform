import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/features/teacher/questions/data/models/bank_models.dart';
import 'package:sat_east_client/features/teacher/questions/domain/entities/bank_filter.dart';

import '../bank_fixtures.dart';

void main() {
  test('QB-06: bank page parses exact RPC shape and nullable ref', () {
    final page = bankPageFromJson(bankJson);
    expect(page.total, 3);
    expect(page.pageSize, 2);
    expect(page.page, 1);
    expect(page.rows.first.stemPreview, r'Solve $x+1=2$.');
    expect(page.rows.last.externalRef, isNull);
    expect(page.rows.first.updatedAt, DateTime.utc(2026, 10, 24, 12));
    expect(page.hasNext, isTrue);
    expect(page.hasPrevious, isFalse);
  });
  test('QB-06: topic tree preserves empty courses and nested metadata', () {
    final topics = bankTopicsFromJson(topicsJson);
    expect(topics.first.courseCode, 'SAT');
    expect(topics.first.topics.first.id, 't1');
    expect(topics.first.topics.first.subtopics.single.slug, 'one-step');
    expect(topics.last.topics, isEmpty);
  });
  for (final raw in <Object?>[
    null,
    [],
    {},
    {...bankJson, 'page_size': 0},
    {...bankJson, 'total': '3'},
    {
      ...bankJson,
      'rows': [
        {'id': 'q1'},
      ],
    },
  ]) {
    test(
      'QB-06: rejects malformed page $raw',
      () => expect(() => bankPageFromJson(raw), throwsFormatException),
    );
  }
  for (final raw in <Object?>[
    null,
    {},
    [
      {'course_code': 'SAT', 'topics': null},
    ],
    [
      {
        'course_code': 'SAT',
        'topics': [
          {'id': 't1'},
        ],
      },
    ],
  ]) {
    test(
      'QB-06: rejects malformed tree $raw',
      () => expect(() => bankTopicsFromJson(raw), throwsFormatException),
    );
  }
  test('QB-06: filter maps all RPC fields without escaping literal search', () {
    const filter = BankFilter(
      courseCode: 'SAT',
      topicId: 't1',
      subtopicId: 's1',
      status: 'draft',
      pool: 'practice',
      difficulty: 'E',
      type: 'mcq',
      q: 'A_%',
    );
    expect(bankFilterToJson(filter), {
      'course_code': 'SAT',
      'topic_id': 't1',
      'subtopic_id': 's1',
      'status': 'draft',
      'pool': 'practice',
      'difficulty': 'E',
      'type': 'mcq',
      'q': 'A_%',
    });
    expect(filter.withValue('courseCode', 'EST').topicId, isNull);
    expect(filter.withValue('courseCode', 'EST').subtopicId, isNull);
    expect(filter.withValue('topicId', 't2').subtopicId, isNull);
    expect(bankFilterToJson(const BankFilter()), isEmpty);
  });
}
