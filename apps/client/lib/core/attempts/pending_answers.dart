import 'package:equatable/equatable.dart';

/// One not-yet-acknowledged snapshot of one question (R4a outbox).
final class PendingAnswer extends Equatable {
  const PendingAnswer({
    required this.answer,
    required this.marked,
    required this.timeMs,
    required this.rev,
    required this.savedAt,
    this.eliminated = const {},
  });

  factory PendingAnswer.fromJson(Map<String, Object?> json) {
    final answer = json['answer'];
    final marked = json['marked'];
    final timeMs = json['time_ms'];
    final rev = json['rev'];
    final savedAt = json['saved_at'];
    // Absent in values written before the mock exam: read as none struck out.
    final eliminated = json['eliminated'];
    if (eliminated != null &&
        (eliminated is! List ||
            eliminated.any((label) => label is! String) ||
            eliminated.toSet().length != eliminated.length)) {
      throw const FormatException('pending answer eliminated');
    }
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
      eliminated: Set.unmodifiable(
        (eliminated as List?)?.cast<String>() ?? const <String>[],
      ),
    );
  }

  final String? answer;
  final bool marked;
  final int timeMs;

  /// Increments on every local change so a late ack cannot drop a newer edit.
  final int rev;
  final DateTime savedAt;

  /// Choice labels struck out (mock eliminator); empty for quizzes.
  final Set<String> eliminated;

  Map<String, Object?> toJson() => {
    'answer': answer,
    'marked': marked,
    'time_ms': timeMs,
    'rev': rev,
    'saved_at': savedAt.toUtc().toIso8601String(),
    'eliminated': eliminated.toList()..sort(),
  };

  @override
  List<Object?> get props => [answer, marked, timeMs, rev, savedAt, eliminated];
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
    Set<String> eliminated,
  });

  int? revOf(String attemptId, String questionId);

  /// Removes the entry only if its stored rev is still [rev].
  void ack(String attemptId, String questionId, int rev);

  Map<String, PendingAnswer> forAttempt(String attemptId);

  void clearAttempt(String attemptId);

  void pruneOlderThan(DateTime cutoff);
}
