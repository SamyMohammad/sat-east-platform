import 'package:equatable/equatable.dart';

enum HomeworkState {
  lockedByPractice,
  available,
  inProgress,
  submitted,
  skipped,
}

class TopicHomework extends Equatable {
  const TopicHomework({
    required this.state,
    this.attemptId,
    this.scorePct,
    this.total,
    this.answered = 0,
  });
  final HomeworkState state;
  final String? attemptId;
  final double? scorePct;
  final int? total;
  final int answered;
  @override
  List<Object?> get props => [state, attemptId, scorePct, total, answered];
}
