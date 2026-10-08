/// Product events (NFR-18, ADR-008). The single place event names live.
///
/// Properties carry ids and numbers only — never names, emails, phones or
/// answers (CLAUDE.md A.6).
sealed class AnalyticsEvent {
  const AnalyticsEvent();

  String get name;

  Map<String, Object> get properties;
}

final class SignedUp extends AnalyticsEvent {
  const SignedUp({required this.method});

  /// `email` or `google` (AUTH-01).
  final String method;

  @override
  String get name => 'signup';

  @override
  Map<String, Object> get properties => {'method': method};
}

/// Sent by the client once the enrolment is visible. The payment itself is
/// verified server-side (PAY-03).
final class Purchased extends AnalyticsEvent {
  const Purchased({
    required this.courseId,
    required this.currency,
    required this.amountMinor,
  });

  final String courseId;
  final String currency;
  final int amountMinor;

  @override
  String get name => 'purchase';

  @override
  Map<String, Object> get properties => {
    'course_id': courseId,
    'currency': currency,
    'amount_minor': amountMinor,
  };
}

/// Topic step from docs/06 `step_kind`.
enum TopicStep { video, notes, practice, homework, quiz }

final class StepCompleted extends AnalyticsEvent {
  const StepCompleted({required this.topicId, required this.step});

  final String topicId;
  final TopicStep step;

  @override
  String get name => 'step_complete';

  @override
  Map<String, Object> get properties => {
    'topic_id': topicId,
    'step': step.name,
  };
}

/// `quiz_pass` or `quiz_fail`, from the server's verdict (never computed in
/// the client — CLAUDE.md rule 2).
final class QuizFinished extends AnalyticsEvent {
  const QuizFinished({
    required this.topicId,
    required this.passed,
    required this.scorePct,
  });

  final String topicId;
  final bool passed;
  final int scorePct;

  @override
  String get name => passed ? 'quiz_pass' : 'quiz_fail';

  @override
  Map<String, Object> get properties => {
    'topic_id': topicId,
    'score_pct': scorePct,
  };
}

final class MockCompleted extends AnalyticsEvent {
  const MockCompleted({required this.mockId, required this.scaledScore});

  final String mockId;
  final int scaledScore;

  @override
  String get name => 'mock_complete';

  @override
  Map<String, Object> get properties => {
    'mock_id': mockId,
    'scaled_score': scaledScore,
  };
}
