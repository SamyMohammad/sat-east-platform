import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/features/topic/data/models/topic_model.dart';
import 'package:sat_east_client/features/topic/domain/entities/topic_detail.dart';
import 'package:sat_east_client/features/topic/domain/entities/topic_homework.dart';

import '../topic_fixture.dart';

void main() {
  for (final state in HomeworkState.values) {
    test('PRC-02: parses homework ${state.name}', () {
      final topic = topicDetailFromJson(
        topicPayload()
          ..['homework'] = {
            'state': switch (state) {
              HomeworkState.lockedByPractice => 'locked_by_practice',
              HomeworkState.inProgress => 'in_progress',
              _ => state.name,
            },
            if (state == HomeworkState.inProgress ||
                state == HomeworkState.submitted) ...{
              'attempt_id': 'hw1',
              'score_pct': 70,
              'total': 20,
              'answered': 8,
            },
          },
      );
      expect(topic.homework.state, state);
      if (state == HomeworkState.submitted) {
        expect(topic.homework.attemptId, 'hw1');
        expect(topic.homework.scorePct, 70);
        expect(topic.homework.total, 20);
        expect(topic.homework.answered, 8);
      }
    });
  }
  test('LRN-01: parses homework_needed quiz state', () {
    expect(
      topicDetailFromJson(topicPayload(state: 'homework_needed')).quiz,
      isA<QuizHomeworkNeeded>(),
    );
  });
  test('PRC-02: rejects unknown homework state', () {
    expect(
      () => topicDetailFromJson(
        topicPayload()..['homework'] = {'state': 'mystery'},
      ),
      throwsFormatException,
    );
  });
}
