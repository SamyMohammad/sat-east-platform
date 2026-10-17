import 'package:equatable/equatable.dart';

enum TopicStatus { open, completed }

class TopicDetail extends Equatable {
  const TopicDetail({
    required this.id,
    required this.title,
    required this.sortLabel,
    required this.status,
    required this.practiceCount,
    required this.practiceMin,
    required this.quiz,
  });

  final String id;
  final String title;
  final String sortLabel;
  final TopicStatus status;
  final int practiceCount;
  final int practiceMin;
  final QuizStatus quiz;

  @override
  List<Object?> get props => [
    id,
    title,
    sortLabel,
    status,
    practiceCount,
    practiceMin,
    quiz,
  ];
}

sealed class QuizStatus extends Equatable {
  const QuizStatus({this.bestScorePct, this.passed = false});

  final double? bestScorePct;
  final bool passed;

  @override
  List<Object?> get props => [bestScorePct, passed];
}

final class QuizAvailable extends QuizStatus {
  const QuizAvailable({super.bestScorePct, super.passed});
}

final class QuizInProgress extends QuizStatus {
  const QuizInProgress({
    required this.attemptId,
    super.bestScorePct,
    super.passed,
  });

  final String attemptId;

  @override
  List<Object?> get props => [...super.props, attemptId];
}

final class QuizPracticeNeeded extends QuizStatus {
  const QuizPracticeNeeded({
    required this.count,
    required this.min,
    super.bestScorePct,
    super.passed,
  });

  final int count;
  final int min;

  int get remaining => min - count;

  @override
  List<Object?> get props => [...super.props, count, min];
}

final class QuizCooldown extends QuizStatus {
  const QuizCooldown({
    required this.availableAt,
    super.bestScorePct,
    super.passed,
  });

  final DateTime availableAt;

  @override
  List<Object?> get props => [...super.props, availableAt];
}
