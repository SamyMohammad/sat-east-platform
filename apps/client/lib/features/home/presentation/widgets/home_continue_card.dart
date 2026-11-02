import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sat_east_client/core/router/app_router.dart';
import 'package:sat_east_client/core/theme/app_colors.dart';
import 'package:sat_east_client/core/theme/app_icons.dart';
import 'package:sat_east_client/core/theme/app_tokens.dart';
import 'package:sat_east_client/features/home/domain/entities/current_step.dart';
import 'package:sat_east_client/features/home/domain/entities/home_summary.dart';
import 'package:sat_east_client/features/home/presentation/home_copy.dart';
import 'package:sat_east_client/features/topic/domain/entities/topic_detail.dart';
import 'package:sat_east_client/features/topic/domain/entities/topic_homework.dart';
import 'package:sat_east_client/shared/widgets/loading_button.dart';

typedef HomeStepAction = ({
  String route,
  String line,
  String name,
  String button,
  IconData icon,
});

HomeStepAction homeStepAction(
  CurrentStep step,
  String topicId, {
  String cooldownTime = '',
}) {
  final (route, line, name, icon) = switch (step) {
    VideoStep(:final video) => (
      AppRoutes.video(topicId, video.assetId),
      HomeCopy.watchVideo,
      HomeCopy.video,
      AppIcons.video,
    ),
    NotesStep(:final note) => (
      AppRoutes.notes(topicId, note.assetId),
      HomeCopy.readNotes,
      HomeCopy.notes,
      AppIcons.notes,
    ),
    PracticeStep(:final count, :final min) => (
      AppRoutes.practice(topicId),
      HomeCopy.practiceCount(count, min),
      HomeCopy.practice,
      AppIcons.workedExample,
    ),
    HomeworkStep(:final homework) => (
      AppRoutes.homework(topicId),
      switch ((homework.state, homework.total)) {
        (HomeworkState.inProgress, final int total) =>
          HomeCopy.homeworkProgress(homework.answered, total),
        (_, final int total) => HomeCopy.homeworkCount(total),
        _ => HomeCopy.homeworkAnswered(homework.answered),
      },
      HomeCopy.homework,
      AppIcons.homework,
    ),
    QuizStep(:final quiz) => (
      switch (quiz) {
        QuizAvailable() || QuizInProgress() => AppRoutes.quiz(topicId),
        QuizCooldown() ||
        QuizPracticeNeeded() ||
        QuizHomeworkNeeded() => AppRoutes.topic(topicId),
      },
      switch (quiz) {
        QuizAvailable() => HomeCopy.takeQuiz,
        QuizInProgress() => HomeCopy.finishQuiz,
        QuizCooldown() => HomeCopy.quizCooldown(cooldownTime),
        QuizPracticeNeeded() || QuizHomeworkNeeded() => HomeCopy.openTopic,
      },
      HomeCopy.quiz,
      AppIcons.quiz,
    ),
  };
  return (
    route: route,
    line: line,
    name: name,
    button: route == AppRoutes.topic(topicId)
        ? HomeCopy.openTopic
        : HomeCopy.continueButton,
    icon: icon,
  );
}

class HomeContinueCard extends StatelessWidget {
  const HomeContinueCard({required this.summary, super.key});
  final HomeReady summary;

  @override
  Widget build(BuildContext context) {
    final action = homeStepAction(
      summary.step,
      summary.topic.topicId,
      cooldownTime: switch (summary.step) {
        QuizStep(quiz: QuizCooldown(:final availableAt)) => _localTime(
          context,
          availableAt,
        ),
        _ => '',
      },
    );
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.s6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpace.s4,
          children: [
            Text(
              summary.firstRun ? HomeCopy.startHere : HomeCopy.continueEyebrow,
              style: theme.textTheme.labelLarge?.copyWith(
                color: context.appColors.inkSecondary,
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: AppSpace.s1,
              children: [
                if (summary.unitTitle.isNotEmpty)
                  Text(summary.unitTitle, style: theme.textTheme.titleSmall),
                Text(
                  HomeCopy.topicTitle(
                    summary.topicSortLabel,
                    summary.topic.title,
                  ),
                  style: theme.textTheme.headlineSmall,
                ),
              ],
            ),
            _StepProgress(
              index: summary.step.index,
              label: HomeCopy.step(summary.step.index, action.name),
            ),
            const Divider(height: AppStroke.thin),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: AppSpace.s3,
              children: [
                Icon(action.icon, size: AppSize.iconSmall),
                Expanded(
                  child: Text(action.line, style: theme.textTheme.titleMedium),
                ),
              ],
            ),
            LoadingButton(
              label: summary.firstRun
                  ? HomeCopy.startTopic(summary.topicSortLabel)
                  : action.button,
              icon: AppIcons.forward,
              expanded:
                  AppLayout.forWidth(MediaQuery.sizeOf(context).width) ==
                  AppLayout.compact,
              onPressed: () => context.go(action.route),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepProgress extends StatelessWidget {
  const _StepProgress({required this.index, required this.label});
  final int index;
  final String label;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpace.s2,
      children: [
        ExcludeSemantics(
          child: Row(
            spacing: AppSpace.s1,
            children: [
              for (var i = 1; i <= 5; i++)
                Expanded(
                  child: Container(
                    height: AppSize.progressThickness,
                    decoration: BoxDecoration(
                      color: i < index
                          ? context.appColors.brand
                          : i == index
                          ? context.appColors.brandWash
                          : context.appColors.line,
                      border: i == index
                          ? Border.all(color: context.appColors.brand)
                          : null,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                  ),
                ),
            ],
          ),
        ),
        ExcludeSemantics(
          child: Text(label, style: Theme.of(context).textTheme.labelLarge),
        ),
      ],
    ),
  );
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
