import 'package:flutter/material.dart';
import 'package:sat_east_client/core/text/text_direction.dart';
import 'package:sat_east_client/core/theme/booklet_tokens.dart';
import 'package:sat_east_client/features/topic/domain/entities/topic_detail.dart';
import 'package:sat_east_client/features/topic/domain/entities/topic_note.dart';
import 'package:sat_east_client/features/topic/domain/entities/topic_video.dart';
import 'package:sat_east_client/features/topic/presentation/topic_copy.dart';
import 'package:sat_east_client/features/topic/presentation/widgets/topic_homework_step.dart';
import 'package:sat_east_client/features/topic/presentation/widgets/topic_notes_step.dart';
import 'package:sat_east_client/features/topic/presentation/widgets/topic_video_step.dart';
import 'package:sat_east_client/shared/widgets/booklet_chip.dart';
import 'package:sat_east_client/shared/widgets/loading_button.dart';

class TopicContent extends StatelessWidget {
  const TopicContent({
    required this.topic,
    required this.onPractice,
    required this.onQuiz,
    super.key,
    this.title,
    this.onNotes,
    this.onVideo,
    this.onHomework,
    this.onReport,
  });

  final TopicDetail topic;
  final String? title;
  final VoidCallback onPractice;
  final VoidCallback onQuiz;
  final ValueChanged<TopicNote>? onNotes;
  final ValueChanged<TopicVideo>? onVideo;
  final VoidCallback? onHomework;
  final ValueChanged<String>? onReport;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final heading = title ?? topic.title;
    final quiz = topic.quiz;
    final description = switch (quiz) {
      QuizHomeworkNeeded() => TopicCopy.homeworkNeeded,
      QuizPracticeNeeded(:final remaining) => TopicCopy.practiceNeeded(
        remaining,
      ),
      QuizCooldown(:final availableAt) => TopicCopy.cooldown(
        _localTime(context, availableAt),
      ),
      QuizAvailable() || QuizInProgress() => null,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: BookletSpace.s4,
      children: [
        Text(topic.sortLabel, style: theme.textTheme.labelLarge),
        Text(
          heading,
          style: theme.textTheme.headlineSmall,
          textDirection: detectTextDirection(heading),
        ),
        if (topic.videos.isNotEmpty)
          TopicVideoStep(
            videos: topic.videos,
            done: topic.videoDone,
            onOpen: onVideo,
          ),
        if (topic.notes.isNotEmpty)
          TopicNotesStep(
            notes: topic.notes,
            done: topic.notesDone,
            lockedByVideo: topic.notesLockedByVideo,
            onOpen: onNotes,
          ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(BookletSpace.s4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: BookletSpace.s3,
              children: [
                Text(
                  TopicCopy.practiceProgress(
                    topic.practiceCount,
                    topic.practiceMin,
                  ),
                ),
                if (topic.practiceLockedByVideo)
                  const Text(TopicCopy.watchVideoFirst)
                else if (topic.practiceLockedByNotes)
                  const Text(TopicCopy.openNotesFirst),
                LoadingButton(
                  label: TopicCopy.practice,
                  onPressed:
                      topic.practiceLockedByVideo || topic.practiceLockedByNotes
                      ? null
                      : onPractice,
                ),
              ],
            ),
          ),
        ),
        TopicHomeworkStep(
          homework: topic.homework,
          onStart: onHomework,
          onReport: onReport,
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(BookletSpace.s4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: BookletSpace.s3,
              children: [
                Text(TopicCopy.quiz, style: theme.textTheme.titleMedium),
                if (quiz.bestScorePct case final score?)
                  Text(TopicCopy.bestScore(score)),
                if (quiz.passed)
                  const BookletChip(
                    label: TopicCopy.passed,
                    icon: Icons.check_circle_outline,
                  ),
                if (description != null) Text(description),
                LoadingButton(
                  label: quiz is QuizInProgress
                      ? TopicCopy.resumeQuiz
                      : TopicCopy.startQuiz,
                  onPressed: switch (quiz) {
                    QuizAvailable() || QuizInProgress() => onQuiz,
                    QuizPracticeNeeded() ||
                    QuizHomeworkNeeded() ||
                    QuizCooldown() => null,
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

String _localTime(BuildContext context, DateTime instant) {
  final local = instant.toLocal();
  final l10n = MaterialLocalizations.of(context);
  final time = l10n.formatTimeOfDay(
    TimeOfDay.fromDateTime(local),
    alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
  );
  return '${l10n.formatMediumDate(local)} $time';
}
