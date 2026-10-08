import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/analytics/analytics_event.dart';

void main() {
  test('NFR-18 events map to the agreed names and id-only properties', () {
    final cases = <AnalyticsEvent, (String, Map<String, Object>)>{
      const SignedUp(method: 'google'): ('signup', {'method': 'google'}),
      const Purchased(courseId: 'c1', currency: 'EGP', amountMinor: 150000): (
        'purchase',
        {'course_id': 'c1', 'currency': 'EGP', 'amount_minor': 150000},
      ),
      const StepCompleted(topicId: 't1', step: TopicStep.notes): (
        'step_complete',
        {'topic_id': 't1', 'step': 'notes'},
      ),
      const QuizFinished(topicId: 't1', passed: true, scorePct: 80): (
        'quiz_pass',
        {'topic_id': 't1', 'score_pct': 80},
      ),
      const QuizFinished(topicId: 't1', passed: false, scorePct: 40): (
        'quiz_fail',
        {'topic_id': 't1', 'score_pct': 40},
      ),
      const MockCompleted(mockId: 'm1', scaledScore: 720): (
        'mock_complete',
        {'mock_id': 'm1', 'scaled_score': 720},
      ),
    };
    for (final MapEntry(key: event, value: (name, props)) in cases.entries) {
      expect(event.name, name);
      expect(event.properties, props);
    }
  });
}
