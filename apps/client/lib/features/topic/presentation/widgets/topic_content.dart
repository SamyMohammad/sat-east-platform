import 'package:flutter/material.dart';
import 'package:sat_east_client/core/theme/app_hues.dart';
import 'package:sat_east_client/core/theme/app_icons.dart';
import 'package:sat_east_client/core/theme/app_tokens.dart';
import 'package:sat_east_client/features/topic/domain/entities/topic_detail.dart';
import 'package:sat_east_client/features/topic/domain/entities/topic_homework.dart';
import 'package:sat_east_client/features/topic/domain/entities/topic_note.dart';
import 'package:sat_east_client/features/topic/domain/entities/topic_video.dart';
import 'package:sat_east_client/features/topic/presentation/topic_copy.dart';
import 'package:sat_east_client/features/topic/presentation/widgets/topic_homework_step.dart';
import 'package:sat_east_client/features/topic/presentation/widgets/topic_notes_step.dart';
import 'package:sat_east_client/features/topic/presentation/widgets/topic_step_row.dart';
import 'package:sat_east_client/features/topic/presentation/widgets/topic_video_step.dart';
import 'package:sat_east_client/shared/widgets/app_chip.dart';
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
      spacing: AppSpace.s4,
      children: [
        Text(
          heading,
          style: theme.textTheme.headlineSmall,
          textDirection: TextDirection.ltr,
        ),
        if (topic.videos.isNotEmpty)
          TopicStepRow(
            icon: AppIcons.video,
            hue: SubjectHue.blue,
            children: [
              TopicVideoStep(
                videos: topic.videos,
                done: topic.videoDone,
                onOpen: onVideo,
              ),
            ],
          ),
        if (topic.notes.isNotEmpty)
          TopicStepRow(
            icon: AppIcons.notes,
            hue: SubjectHue.teal,
            children: [
              TopicNotesStep(
                notes: topic.notes,
                done: topic.notesDone,
                lockedByVideo: topic.notesLockedByVideo,
                onOpen: onNotes,
              ),
            ],
          ),
        TopicStepRow(
          icon: AppIcons.workedExample,
          hue: SubjectHue.violet,
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
              variant: topic.practiceComplete
                  ? AppButtonVariant.secondary
                  : AppButtonVariant.primary,
              onPressed:
                  topic.practiceLockedByVideo || topic.practiceLockedByNotes
                  ? null
                  : onPractice,
            ),
          ],
        ),
        if (topic.homework.state != HomeworkState.skipped)
          TopicStepRow(
            icon: AppIcons.homework,
            hue: SubjectHue.amber,
            children: [
              TopicHomeworkStep(
                homework: topic.homework,
                onStart: onHomework,
                onReport: onReport,
              ),
            ],
          ),
        TopicStepRow(
          icon: AppIcons.quiz,
          hue: SubjectHue.rose,
          children: [
            Text(TopicCopy.quiz, style: theme.textTheme.titleMedium),
            if (quiz.bestScorePct case final score?)
              Text(TopicCopy.bestScore(score)),
            if (quiz.passed)
              const AppChip(
                label: TopicCopy.passed,
                icon: AppIcons.correct,
              ),
            if (description != null)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: AppSpace.s2,
                children: [
                  const Icon(AppIcons.locked, size: AppSize.iconSmall),
                  Expanded(child: Text(description)),
                ],
              ),
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
