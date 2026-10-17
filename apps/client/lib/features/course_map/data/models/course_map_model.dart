import 'package:sat_east_client/features/course_map/domain/entities/course_map.dart';

/// Parses the `get_course_map` payload; throws [FormatException] when a
/// field is missing, mistyped or unknown.
CourseMap courseMapFromJson(Map<String, Object?> json) {
  final course = _map(json, 'course');
  final cont = json['continue'];
  return CourseMap(
    courseId: _str(course, 'id'),
    slug: _str(course, 'slug'),
    title: _str(course, 'title'),
    continueTopic: cont == null ? null : _continue(_asMap(cont, 'continue')),
    units: [
      for (final u in _list(json, 'units')) _unit(_asMap(u, 'units[]')),
    ],
  );
}

ContinueTopic _continue(Map<String, Object?> json) => ContinueTopic(
  topicId: _str(json, 'topic_id'),
  slug: _str(json, 'slug'),
  title: _str(json, 'title'),
  unitTitle: _optStr(json, 'unit_title'),
);

MapUnit _unit(Map<String, Object?> json) => MapUnit(
  title: _optStr(json, 'title'),
  topics: [
    for (final t in _list(json, 'topics')) _topic(_asMap(t, 'topics[]')),
  ],
);

MapTopic _topic(Map<String, Object?> json) {
  final status = switch (_str(json, 'status')) {
    'completed' => TopicStatus.completed,
    'open' => TopicStatus.open,
    'locked' => TopicStatus.locked,
    final other => throw FormatException('unknown status: $other'),
  };
  final LockReason? reason = switch (json['locked_reason']) {
    null => null,
    'previous_quiz' => PreviousQuiz(_str(json, 'after_title')),
    final other => throw FormatException('unknown locked_reason: $other'),
  };
  return MapTopic(
    id: _str(json, 'id'),
    slug: _str(json, 'slug'),
    title: _str(json, 'title'),
    sortLabel: _str(json, 'sort_label'),
    isFreePreview: _bool(json, 'is_free_preview'),
    status: status,
    lockReason: reason,
  );
}

Map<String, Object?> _asMap(Object? v, String what) =>
    v is Map ? v.cast<String, Object?>() : throw FormatException(what);

Map<String, Object?> _map(Map<String, Object?> json, String key) =>
    _asMap(json[key], key);

List<Object?> _list(Map<String, Object?> json, String key) {
  final v = json[key];
  return v is List ? v.cast<Object?>() : throw FormatException(key);
}

String _str(Map<String, Object?> json, String key) {
  final v = json[key];
  return v is String ? v : throw FormatException(key);
}

String? _optStr(Map<String, Object?> json, String key) {
  final v = json[key];
  if (v == null) return null;
  return v is String ? v : throw FormatException(key);
}

bool _bool(Map<String, Object?> json, String key) {
  final v = json[key];
  return v is bool ? v : throw FormatException(key);
}
