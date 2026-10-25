import 'package:flutter_test/flutter_test.dart';

import 'package:sat_east_client/features/topic/data/models/topic_model.dart';
import 'package:sat_east_client/features/topic/domain/entities/topic_detail.dart';

import '../topic_fixture.dart';

void main() {
  test('LRN-02: parses videos and server completion flag', () {
    final topic = topicDetailFromJson(
      topicPayload()..addAll({
        'videos': [
          {
            'asset_id': 'v1',
            'title': 'Lesson',
            'subtopic_title': null,
            'duration_s': 600,
            'provider': 'r2_hls',
            'pct': 40,
            'last_position_s': 120,
          },
        ],
        'video_done': false,
      }),
    );
    final video = topic.videos.single;
    expect(video.assetId, 'v1');
    expect(video.title, 'Lesson');
    expect(video.subtopicTitle, isNull);
    expect(video.durationS, 600);
    expect(video.provider.name, 'r2Hls');
    expect(video.pct, 40);
    expect(video.lastPositionS, 120);
    expect(topic.videoDone, isFalse);
  });
  test('LRN-02: missing video fields preserve topics without videos', () {
    final topic = topicDetailFromJson(topicPayload());
    expect(topic.videos, isEmpty);
    expect(topic.videoDone, isTrue);
  });
  for (final provider in ['youtube', 'unknown']) {
    test('LRN-02: validates video provider $provider', () {
      final payload = topicPayload()
        ..['videos'] = [
          {
            'asset_id': 'v1',
            'title': 'Lesson',
            'duration_s': 600,
            'provider': provider,
            'pct': 40,
            'last_position_s': 120,
          },
        ];
      if (provider == 'unknown') {
        expect(() => topicDetailFromJson(payload), throwsFormatException);
      } else {
        expect(
          topicDetailFromJson(payload).videos.single.provider.name,
          'youtube',
        );
      }
    });
  }
  test('L-3: parses notes and server completion flag', () {
    final payload = topicPayload()
      ..addAll({
        'notes': [
          {
            'asset_id': 'a1',
            'title': 'Notes',
            'subtopic_title': null,
            'page_count': 4,
          },
        ],
        'notes_done': false,
      });
    final topic = topicDetailFromJson(payload);
    expect(topic.notes.single.assetId, 'a1');
    expect(topic.notes.single.pageCount, 4);
    expect(topic.notesDone, isFalse);
    expect(topic.practiceLockedByNotes, isTrue);
  });
  for (final value in <Object?>[
    null,
    {},
    [
      {'asset_id': 1},
    ],
  ]) {
    test('L-3: rejects malformed notes $value', () {
      expect(
        () => topicDetailFromJson(topicPayload()..['notes'] = value),
        throwsFormatException,
      );
    });
  }

  test('PRC-03: parses topic identity and server practice progress', () {
    final topic = topicDetailFromJson(topicPayload());
    expect(topic.id, 't1');
    expect(topic.title, 'Linear equations');
    expect(topic.sortLabel, '1.1');
    expect(topic.status, TopicStatus.open);
    expect(topic.practiceCount, 10);
    expect(topic.practiceMin, 10);
    expect(topic.quiz, isA<QuizAvailable>());
    expect(topic.quiz.bestScorePct, isNull);
    expect(topic.quiz.passed, isFalse);
  });

  test('PRC-03: parses resumed quiz attempt', () {
    final quiz = topicDetailFromJson(topicPayload(state: 'in_progress')).quiz;
    expect((quiz as QuizInProgress).attemptId, 'a1');
  });

  test('PRC-03: practice gate uses quiz state counts', () {
    final payload = topicPayload(state: 'practice_needed');
    (payload['quiz']! as Map<String, Object?>)['practice_count'] = 4;
    final quiz = topicDetailFromJson(payload).quiz as QuizPracticeNeeded;
    expect(quiz.count, 4);
    expect(quiz.min, 10);
    expect(quiz.remaining, 6);
  });

  test('PRC-03: parses cooldown instant', () {
    final quiz = topicDetailFromJson(topicPayload(state: 'cooldown')).quiz;
    expect(
      (quiz as QuizCooldown).availableAt,
      DateTime.utc(2026, 10, 18, 12, 30),
    );
  });

  test('PRC-03: completed retake keeps best score and pass', () {
    final payload = topicPayload()..['status'] = 'completed';
    (payload['quiz']! as Map<String, Object?>).addAll({
      'best_score_pct': 83.33,
      'passed': true,
    });
    final topic = topicDetailFromJson(payload);
    expect(topic.status, TopicStatus.completed);
    expect(topic.quiz.bestScorePct, 83.33);
    expect(topic.quiz.passed, isTrue);
  });

  for (final (field, value) in <(String, Object?)>[
    ('id', null),
    ('title', 3),
    ('sort_label', null),
    ('status', 'locked'),
    ('practice', null),
    ('quiz', null),
  ]) {
    test('PRC-03: rejects invalid topic $field', () {
      final payload = topicPayload()..[field] = value;
      expect(() => topicDetailFromJson(payload), throwsFormatException);
    });
  }

  for (final (field, value) in <(String, Object?)>[
    ('state', 'future'),
    ('practice_count', -1),
    ('practice_count', 1.5),
    ('practice_min', '10'),
    ('passed', 'yes'),
    ('best_score_pct', '75'),
    ('best_score_pct', -1),
    ('best_score_pct', 101),
  ]) {
    test('PRC-03: rejects invalid quiz $field=$value', () {
      final payload = topicPayload();
      (payload['quiz']! as Map<String, Object?>)[field] = value;
      expect(() => topicDetailFromJson(payload), throwsFormatException);
    });
  }

  test('PRC-03: rejects resumed quiz without attempt id', () {
    final payload = topicPayload(state: 'in_progress');
    (payload['quiz']! as Map<String, Object?>).remove('attempt_id');
    expect(() => topicDetailFromJson(payload), throwsFormatException);
  });

  for (final (field, value) in <(String, Object?)>[
    ('count', -1),
    ('count', 1.5),
    ('min', null),
    ('min', '10'),
  ]) {
    test('PRC-03: rejects invalid practice $field=$value', () {
      final payload = topicPayload();
      (payload['practice']! as Map<String, Object?>)[field] = value;
      expect(() => topicDetailFromJson(payload), throwsFormatException);
    });
  }

  test('PRC-03: rejects cooldown without timestamp', () {
    final payload = topicPayload(state: 'cooldown');
    (payload['quiz']! as Map<String, Object?>)['available_at'] = 'tomorrow';
    expect(() => topicDetailFromJson(payload), throwsFormatException);
  });
}
