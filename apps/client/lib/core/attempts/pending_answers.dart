import 'package:equatable/equatable.dart';

/// One not-yet-acknowledged snapshot of one question (R4a outbox).
final class PendingAnswer extends Equatable {
  const PendingAnswer({
    required this.answer,
    required this.marked,
    required this.timeMs,
    required this.rev,
    required this.savedAt,
  });

  factory PendingAnswer.fromJson(Map<String, Object?> json) {
    final answer = json['answer'];
    final marked = json['marked'];
    final timeMs = json['time_ms'];
    final rev = json['rev'];
    final savedAt = json['saved_at'];
    if ((answer != null && answer is! String) ||
        marked is! bool ||
        timeMs is! int ||
        rev is! int ||
        savedAt is! String) {
      throw const FormatException('pending answer');
    }
    return PendingAnswer(
      answer: answer as String?,
      marked: marked,
      timeMs: timeMs,
      rev: rev,
      savedAt: DateTime.parse(savedAt),
    );
  }

  final String? answer;
  final bool marked;
  final int timeMs;

  /// Increments on every local change so a late ack cannot drop a newer edit.
  final int rev;
  final DateTime savedAt;

  Map<String, Object?> toJson() => {
    'answer': answer,
    'marked': marked,
    'time_ms': timeMs,
    'rev': rev,
    'saved_at': savedAt.toUtc().toIso8601String(),
  };

  @override
  List<Object?> get props => [answer, marked, timeMs, rev, savedAt];
}

/// Local store of answers the server has not acknowledged yet. Synchronous so
/// cubits can record a change in the same turn they emit it.
abstract interface class PendingAnswers {
  /// Stores the latest snapshot and returns its new rev (starts at 1).
  int put(
    String attemptId,
    String questionId, {
    required bool marked,
    required int timeMs,
    String? answer,
  });

  int? revOf(String attemptId, String questionId);

  /// Removes the entry only if its stored rev is still [rev].
  void ack(String attemptId, String questionId, int rev);

  Map<String, PendingAnswer> forAttempt(String attemptId);

  void clearAttempt(String attemptId);

  void pruneOlderThan(DateTime cutoff);
}
