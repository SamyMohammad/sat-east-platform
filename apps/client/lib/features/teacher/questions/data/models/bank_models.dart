import 'package:sat_east_client/features/teacher/questions/domain/entities/bank_filter.dart';
import 'package:sat_east_client/features/teacher/questions/domain/entities/bank_page.dart';
import 'package:sat_east_client/features/teacher/questions/domain/entities/bank_row.dart';
import 'package:sat_east_client/features/teacher/questions/domain/entities/topic_option.dart';

BankPage bankPageFromJson(Object? raw) {
  final json = _object(raw);
  return BankPage(
    total: _count(json['total']),
    page: _count(json['page'], min: 1),
    pageSize: _count(json['page_size'], min: 1),
    rows: _array(json['rows']).map((raw) {
      final row = _object(raw);
      final updated = DateTime.tryParse(_text(row['updated_at']));
      if (updated == null) throw const FormatException('updated_at');
      return BankRow(
        id: _text(row['id']),
        externalRef: _optionalText(row['external_ref']),
        stemPreview: _text(row['stem_preview']),
        type: _text(row['type']),
        topicTitle: _text(row['topic_title']),
        subtopicTitle: _text(row['subtopic_title']),
        difficulty: _text(row['difficulty']),
        pool: _text(row['pool']),
        status: _text(row['status']),
        version: _count(row['version'], min: 1),
        updatedAt: updated,
      );
    }).toList(),
  );
}

List<BankCourse> bankTopicsFromJson(Object? raw) => _array(raw).map((raw) {
  final course = _object(raw);
  return BankCourse(
    courseCode: _text(course['course_code']),
    topics: _array(course['topics']).map((raw) {
      final topic = _object(raw);
      return TopicOption(
        id: _text(topic['id']),
        slug: _text(topic['slug']),
        title: _text(topic['title']),
        subtopics: _array(topic['subtopics']).map((raw) {
          final sub = _object(raw);
          return SubtopicOption(
            id: _text(sub['id']),
            slug: _text(sub['slug']),
            title: _text(sub['title']),
          );
        }).toList(),
      );
    }).toList(),
  );
}).toList();
Map<String, Object?> _object(Object? raw) {
  if (raw is! Map<String, Object?>) throw const FormatException('object');
  return raw;
}

List<Object?> _array(Object? raw) {
  if (raw is! List<Object?>) throw const FormatException('array');
  return raw;
}

String _text(Object? raw) {
  if (raw is! String) throw const FormatException('text');
  return raw;
}

String? _optionalText(Object? raw) => raw == null ? null : _text(raw);
int _count(Object? raw, {int min = 0}) {
  if (raw is! int || raw < min) throw const FormatException('count');
  return raw;
}

Map<String, String> bankFilterToJson(BankFilter filter) => {
  'course_code': ?filter.courseCode,
  'topic_id': ?filter.topicId,
  'subtopic_id': ?filter.subtopicId,
  'status': ?filter.status,
  'pool': ?filter.pool,
  'difficulty': ?filter.difficulty,
  'type': ?filter.type,
  if (filter.q.isNotEmpty) 'q': filter.q,
};
