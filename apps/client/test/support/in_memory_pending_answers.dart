import 'package:sat_east_client/core/attempts/pending_answers.dart';

/// In-memory [PendingAnswers] for cubit tests; mirrors the Hive rev rules.
class InMemoryPendingAnswers implements PendingAnswers {
  InMemoryPendingAnswers({DateTime Function()? now})
    : _now = now ?? (() => DateTime.utc(2026, 11, 11));

  final DateTime Function() _now;
  final _entries = <String, Map<String, PendingAnswer>>{};

  /// Attempt IDs passed to [clearAttempt], in call order.
  final cleared = <String>[];

  @override
  int put(
    String attemptId,
    String questionId, {
    required bool marked,
    required int timeMs,
    String? answer,
  }) {
    final rev = (revOf(attemptId, questionId) ?? 0) + 1;
    (_entries[attemptId] ??= {})[questionId] = PendingAnswer(
      answer: answer,
      marked: marked,
      timeMs: timeMs,
      rev: rev,
      savedAt: _now(),
    );
    return rev;
  }

  @override
  int? revOf(String attemptId, String questionId) =>
      _entries[attemptId]?[questionId]?.rev;

  @override
  void ack(String attemptId, String questionId, int rev) {
    if (revOf(attemptId, questionId) == rev) {
      _entries[attemptId]!.remove(questionId);
    }
  }

  @override
  Map<String, PendingAnswer> forAttempt(String attemptId) =>
      Map.of(_entries[attemptId] ?? const {});

  @override
  void clearAttempt(String attemptId) {
    cleared.add(attemptId);
    _entries.remove(attemptId);
  }

  @override
  void pruneOlderThan(DateTime cutoff) {}
}
