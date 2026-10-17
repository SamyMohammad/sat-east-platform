import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/features/course_map/data/models/course_map_model.dart';
import 'package:sat_east_client/features/course_map/domain/entities/course_map.dart';

Map<String, Object?> _topic(
  String id, {
  String status = 'open',
  String sortLabel = '1.1',
  Object? lockedReason,
  Object? afterTitle,
}) => {
  'id': id,
  'slug': 's-$id',
  'title': 'T $id',
  'sort_label': sortLabel,
  'is_free_preview': false,
  'status': status,
  'locked_reason': lockedReason,
  'after_title': afterTitle,
};

Map<String, Object?> _json({Object? cont, List<Object?>? units}) => {
  'course': {'id': 'c1', 'slug': 'sat-math', 'title': 'SAT Math'},
  'continue': cont,
  'units':
      units ??
      [
        {
          'title': 'Algebra',
          'topics': [
            _topic('t1', status: 'completed'),
            _topic(
              't2',
              status: 'locked',
              sortLabel: '2.1',
              lockedReason: 'previous_quiz',
              afterTitle: 'A',
            ),
          ],
        },
        {
          'title': null,
          'topics': [_topic('t3', sortLabel: '3')],
        },
      ],
};

void main() {
  group('L-1: courseMapFromJson', () {
    test('L-1: parses the spec example', () {
      final map = courseMapFromJson(
        _json(
          cont: {
            'topic_id': 't3',
            'slug': 's-t3',
            'title': 'T t3',
            'unit_title': null,
          },
        ),
      );

      expect(map.courseId, 'c1');
      expect(map.slug, 'sat-math');
      expect(map.title, 'SAT Math');
      expect(map.continueTopic?.topicId, 't3');
      expect(map.continueTopic?.unitTitle, isNull);
      expect(map.units, hasLength(2));
      expect(map.units[0].title, 'Algebra');
      expect(map.units[1].title, isNull);
      final topics = map.units[0].topics;
      expect(topics[0].status, TopicStatus.completed);
      expect(topics[0].lockReason, isNull);
      expect(topics[1].status, TopicStatus.locked);
      expect(topics[1].sortLabel, '2.1');
      expect(topics[1].lockReason, const PreviousQuiz('A'));
      expect(map.units[1].topics.single.status, TopicStatus.open);
    });

    test('L-1: continue null gives null continueTopic', () {
      expect(courseMapFromJson(_json()).continueTopic, isNull);
    });

    test('L-1: unknown status throws FormatException', () {
      final json = _json(
        units: [
          {
            'title': null,
            'topics': [_topic('t1', status: 'weird')],
          },
        ],
      );
      expect(() => courseMapFromJson(json), throwsFormatException);
    });

    test('L-1: previous_quiz without after_title throws FormatException', () {
      final json = _json(
        units: [
          {
            'title': null,
            'topics': [
              _topic('t1', status: 'locked', lockedReason: 'previous_quiz'),
            ],
          },
        ],
      );
      expect(() => courseMapFromJson(json), throwsFormatException);
    });

    test('L-1: missing course throws FormatException', () {
      final json = _json()..remove('course');
      expect(() => courseMapFromJson(json), throwsFormatException);
    });
  });
}
