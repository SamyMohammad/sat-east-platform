import 'package:sat_east_client/features/topic/domain/entities/topic_detail.dart';

const topicFixture = TopicDetail(
  id: 't1',
  title: 'Linear equations',
  sortLabel: '1.1',
  status: TopicStatus.open,
  practiceCount: 10,
  practiceMin: 10,
  quiz: QuizAvailable(),
);

Map<String, Object?> topicPayload({String state = 'available'}) => {
  'id': 't1',
  'title': 'Linear equations',
  'slug': 'linear-equations',
  'sort_label': '1.1',
  'status': 'open',
  'notes': <Object?>[],
  'notes_done': true,
  'practice': <String, Object?>{'count': 10, 'min': 10},
  'quiz': {
    'state': state,
    'practice_count': 10,
    'practice_min': 10,
    'best_score_pct': null,
    'passed': false,
    if (state == 'in_progress') 'attempt_id': 'a1',
    if (state == 'cooldown') 'available_at': '2026-10-18T12:30:00Z',
  },
};
