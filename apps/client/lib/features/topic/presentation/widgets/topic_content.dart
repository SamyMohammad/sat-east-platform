import 'package:flutter/material.dart';
import 'package:sat_east_client/core/text/text_direction.dart';
import 'package:sat_east_client/core/theme/booklet_tokens.dart';
import 'package:sat_east_client/features/topic/domain/entities/topic_detail.dart';
import 'package:sat_east_client/features/topic/presentation/topic_copy.dart';
import 'package:sat_east_client/shared/widgets/booklet_chip.dart';
import 'package:sat_east_client/shared/widgets/loading_button.dart';

class TopicContent extends StatelessWidget {
  const TopicContent({
    required this.topic,
    required this.onPractice,
    required this.onQuiz,
    super.key,
    this.title,
  });

  final TopicDetail topic;
  final String? title;
  final VoidCallback onPractice;
  final VoidCallback onQuiz;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final heading = title ?? topic.title;
    final quiz = topic.quiz;
    final description = switch (quiz) {
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
                LoadingButton(label: TopicCopy.practice, onPressed: onPractice),
              ],
            ),
          ),
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
                    QuizPracticeNeeded() || QuizCooldown() => null,
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
