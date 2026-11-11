import 'package:equatable/equatable.dart';
import 'package:sat_east_client/features/topic/domain/entities/topic_detail.dart';
import 'package:sat_east_client/features/topic/domain/entities/topic_homework.dart';
import 'package:sat_east_client/features/topic/domain/entities/topic_note.dart';
import 'package:sat_east_client/features/topic/domain/entities/topic_video.dart';

sealed class CurrentStep extends Equatable {
  const CurrentStep();
  int get index;
}

final class VideoStep extends CurrentStep {
  const VideoStep(this.video);
  final TopicVideo video;
  @override
  int get index => 1;
  @override
  List<Object?> get props => [video];
}

final class NotesStep extends CurrentStep {
  const NotesStep(this.note);
  final TopicNote note;
  @override
  int get index => 2;
  @override
  List<Object?> get props => [note];
}

final class PracticeStep extends CurrentStep {
  const PracticeStep(this.count, this.min);
  final int count;
  final int min;
  @override
  int get index => 3;
  @override
  List<Object?> get props => [count, min];
}

final class HomeworkStep extends CurrentStep {
  const HomeworkStep(this.homework);
  final TopicHomework homework;
  @override
  int get index => 4;
  @override
  List<Object?> get props => [homework];
}

final class QuizStep extends CurrentStep {
  const QuizStep(this.quiz);
  final QuizStatus quiz;
  @override
  int get index => 5;
  @override
  List<Object?> get props => [quiz];
}

CurrentStep currentStepOf(TopicDetail topic) {
  if (!topic.videoDone && topic.videos.isNotEmpty) {
    return VideoStep(
      topic.videos.firstWhere(
        (video) => video.pct < 100,
        orElse: () => topic.videos.first,
      ),
    );
  }
  if (!topic.notesDone && topic.notes.isNotEmpty) {
    return NotesStep(topic.notes.first);
  }
  if (topic.practiceCount < topic.practiceMin) {
    return PracticeStep(topic.practiceCount, topic.practiceMin);
  }
  return switch (topic.homework.state) {
    HomeworkState.submitted || HomeworkState.skipped => QuizStep(topic.quiz),
    HomeworkState.lockedByPractice ||
    HomeworkState.available ||
    HomeworkState.inProgress => HomeworkStep(topic.homework),
  };
}
