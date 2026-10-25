import 'package:sat_east_client/core/attempts/attempt_json.dart';
import 'package:sat_east_client/core/video/video_provider.dart';
import 'package:sat_east_client/features/topic/domain/entities/topic_detail.dart';
import 'package:sat_east_client/features/topic/domain/entities/topic_homework.dart';
import 'package:sat_east_client/features/topic/domain/entities/topic_note.dart';
import 'package:sat_east_client/features/topic/domain/entities/topic_video.dart';

TopicDetail topicDetailFromJson(Map<String, Object?> json) {
  final practice = _map(json['practice']);
  _string(json, 'slug');
  final done = json['notes_done'];
  if (done is! bool) throw const FormatException('notes_done');
  final videoDone = json.containsKey('video_done') ? json['video_done'] : true;
  if (videoDone is! bool) throw const FormatException('video_done');
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
    homework: json.containsKey('homework')
        ? _homework(_map(json['homework']))
        : const TopicHomework(state: HomeworkState.skipped),
    notes: _notes(json['notes']),
    notesDone: done,
    videos: json.containsKey('videos') ? _videos(json['videos']) : const [],
    videoDone: videoDone,
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
    'homework_needed' => QuizHomeworkNeeded(
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

List<TopicVideo> _videos(Object? raw) {
  if (raw is! List<Object?>) throw const FormatException('videos');
  return List.unmodifiable(
    raw.map((item) {
      final json = _map(item);
      final duration = _count(json, 'duration_s');
      final pct = _count(json, 'pct');
      if (duration == 0 || pct > 100) throw const FormatException('video');
      return TopicVideo(
        assetId: _string(json, 'asset_id'),
        title: _string(json, 'title'),
        subtopicTitle: json['subtopic_title'] == null
            ? null
            : _string(json, 'subtopic_title'),
        durationS: duration,
        provider: VideoProvider.fromWire(_string(json, 'provider')),
        pct: pct,
        lastPositionS: _count(json, 'last_position_s'),
      );
    }),
  );
}

TopicHomework _homework(Map<String, Object?> json) {
  final state = switch (_string(json, 'state')) {
    'locked_by_practice' => HomeworkState.lockedByPractice,
    'available' => HomeworkState.available,
    'in_progress' => HomeworkState.inProgress,
    'submitted' => HomeworkState.submitted,
    'skipped' => HomeworkState.skipped,
    _ => throw const FormatException('homework state'),
  };
  final active =
      state == HomeworkState.inProgress || state == HomeworkState.submitted;
  final score = json['score_pct'];
  if (state == HomeworkState.submitted && score == null) {
    throw const FormatException('score_pct');
  }
  final total = active ? _count(json, 'total') : null;
  final answered = json.containsKey('answered') ? _count(json, 'answered') : 0;
  if (active && (total == 0 || answered > total!)) {
    throw const FormatException('answered');
  }
  return TopicHomework(
    state: state,
    attemptId: active ? _string(json, 'attempt_id') : null,
    scorePct: score == null ? null : attemptJsonPercentage(json, 'score_pct'),
    total: total,
    answered: answered,
  );
}
