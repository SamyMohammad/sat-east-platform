import 'package:sat_east_client/features/quiz/domain/entities/quiz.dart';

/// Keeps server-relative countdown separate from time spent viewing a question.
class QuizAttemptClock {
  QuizAttemptClock(QuizSession session, DateTime Function() now)
    : _now = now,
      _deadline = session.deadline,
      _offset = session.serverNow.difference(now());

  final DateTime Function() _now;
  final DateTime _deadline;
  final Duration _offset;
  final _elapsed = <String, int>{};
  String? _shownId;
  DateTime? _shownAt;

  Duration get remaining {
    final value = _deadline.difference(_now().add(_offset));
    return value.isNegative ? Duration.zero : value;
  }

  int timeMs(String questionId) {
    final shownAt = _shownAt;
    final elapsed = _elapsed[questionId] ?? 0;
    if (_shownId != questionId || shownAt == null) return elapsed;
    final visible = _now().difference(shownAt).inMilliseconds;
    return elapsed + (visible < 0 ? 0 : visible);
  }

  void show(String questionId) {
    pause();
    _shownId = questionId;
    _shownAt = _now();
  }

  void pause() {
    final id = _shownId;
    if (id != null) _elapsed[id] = timeMs(id);
    _shownId = null;
    _shownAt = null;
  }
}
