import 'package:flutter/material.dart';
import 'package:sat_east_client/core/text/text_direction.dart';
import 'package:sat_east_client/core/theme/app_hues.dart';
import 'package:sat_east_client/core/theme/app_icons.dart';
import 'package:sat_east_client/core/theme/app_tokens.dart';
import 'package:sat_east_client/features/topic/domain/entities/topic_detail.dart';
import 'package:sat_east_client/features/topic/presentation/topic_copy.dart';
import 'package:sat_east_client/features/topic/presentation/widgets/topic_step_row.dart';
import 'package:sat_east_client/shared/widgets/app_chip.dart';
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
      spacing: AppSpace.s4,
      children: [
        Text(topic.sortLabel, style: theme.textTheme.labelLarge),
        Text(
          heading,
          style: theme.textTheme.headlineSmall,
          textDirection: detectTextDirection(heading),
        ),
        TopicStepRow(
          icon: AppIcons.workedExample,
          hue: SubjectHue.violet,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: AppSpace.s2,
              children: [
                const Icon(AppIcons.workedExample, size: AppSize.iconSmall),
                Expanded(
                  child: Text(
                    TopicCopy.practiceProgress(
                      topic.practiceCount,
                      topic.practiceMin,
                    ),
                  ),
                ),
              ],
            ),
            LoadingButton(label: TopicCopy.practice, onPressed: onPractice),
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
                QuizPracticeNeeded() || QuizCooldown() => null,
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
