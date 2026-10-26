import 'package:equatable/equatable.dart';
import 'package:sat_east_client/features/topic/domain/entities/topic_homework.dart';
import 'package:sat_east_client/features/topic/domain/entities/topic_note.dart';
import 'package:sat_east_client/features/topic/domain/entities/topic_video.dart';

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
    this.homework = const TopicHomework(state: HomeworkState.skipped),
    this.notes = const [],
    this.notesDone = true,
    this.videos = const [],
    this.videoDone = true,
  });

  final String id;
  final String title;
  final String sortLabel;
  final TopicStatus status;
  final int practiceCount;
  final int practiceMin;
  final QuizStatus quiz;
  final TopicHomework homework;
  final List<TopicNote> notes;
  final bool notesDone;
  final List<TopicVideo> videos;
  final bool videoDone;

  bool get notesLockedByVideo => videos.isNotEmpty && !videoDone;
  bool get practiceLockedByVideo => notesLockedByVideo;

  bool get practiceLockedByNotes => notes.isNotEmpty && !notesDone;

  @override
  List<Object?> get props => [
    id,
    title,
    sortLabel,
    status,
    practiceCount,
    practiceMin,
    quiz,
    homework,
    notes,
    notesDone,
    videos,
    videoDone,
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

final class QuizHomeworkNeeded extends QuizStatus {
  const QuizHomeworkNeeded({super.bestScorePct, super.passed});
}
