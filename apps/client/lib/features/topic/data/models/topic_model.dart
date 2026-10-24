import 'package:sat_east_client/features/topic/domain/entities/topic_detail.dart';
import 'package:sat_east_client/features/topic/domain/entities/topic_note.dart';

TopicDetail topicDetailFromJson(Map<String, Object?> json) {
  final practice = _map(json['practice']);
  _string(json, 'slug');
  final done = json['notes_done'];
  if (done is! bool) throw const FormatException('notes_done');
  return TopicDetail(
    id: _string(json, 'id'),
    title: _string(json, 'title'),
    sortLabel: _string(json, 'sort_label'),
    status: switch (_string(json, 'status')) {
      'open' => TopicStatus.open,
      'completed' => TopicStatus.completed,
      _ => throw const FormatException('status'),
    },
    practiceCount: _count(practice, 'count'),
    practiceMin: _count(practice, 'min'),
    quiz: _quiz(_map(json['quiz'])),
    notes: _notes(json['notes']),
    notesDone: done,
  );
}

QuizStatus _quiz(Map<String, Object?> json) {
  final count = _count(json, 'practice_count');
  final min = _count(json, 'practice_min');
  final rawScore = json['best_score_pct'];
  if (!json.containsKey('best_score_pct') ||
      (rawScore != null &&
          (rawScore is! num ||
              !rawScore.isFinite ||
              rawScore < 0 ||
              rawScore > 100))) {
    throw const FormatException('best_score_pct');
  }
  final score = (rawScore as num?)?.toDouble();
  final passed = json['passed'];
  if (passed is! bool) throw const FormatException('passed');
  return switch (_string(json, 'state')) {
    'available' => QuizAvailable(bestScorePct: score, passed: passed),
    'in_progress' => QuizInProgress(
      attemptId: _string(json, 'attempt_id'),
      bestScorePct: score,
      passed: passed,
    ),
    'practice_needed' => QuizPracticeNeeded(
      count: count,
      min: min,
      bestScorePct: score,
      passed: passed,
    ),
    'cooldown' => QuizCooldown(
      availableAt: _instant(json, 'available_at'),
      bestScorePct: score,
      passed: passed,
    ),
    _ => throw const FormatException('quiz state'),
  };
}

Map<String, Object?> _map(Object? value) => value is Map<String, Object?>
    ? value
    : throw const FormatException('object');

String _string(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) throw FormatException(key);
  return value;
}

int _count(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! int || value < 0) throw FormatException(key);
  return value;
}

DateTime _instant(Map<String, Object?> json, String key) {
  final value = DateTime.tryParse(_string(json, key));
  if (value == null || !value.isUtc) throw FormatException(key);
  return value;
}

List<TopicNote> _notes(Object? raw) {
  if (raw is! List<Object?>) throw const FormatException('notes');
  return List.unmodifiable(
    raw.map((item) {
      final json = _map(item);
      return TopicNote(
        assetId: _string(json, 'asset_id'),
        title: _string(json, 'title'),
        subtopicTitle: json['subtopic_title'] == null
            ? null
            : _string(json, 'subtopic_title'),
        pageCount: json['page_count'] == null
            ? null
            : _count(json, 'page_count'),
      );
    }),
  );
}
