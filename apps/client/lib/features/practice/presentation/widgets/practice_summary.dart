import 'package:flutter/material.dart';

import 'package:sat_east_client/core/presentation/learning_copy.dart';
import 'package:sat_east_client/core/theme/app_colors.dart';
import 'package:sat_east_client/core/theme/app_tokens.dart';
import 'package:sat_east_client/core/theme/app_type.dart';
import 'package:sat_east_client/features/practice/presentation/practice_copy.dart';
import 'package:sat_east_client/shared/widgets/app_illustration.dart';
import 'package:sat_east_client/shared/widgets/loading_button.dart';

class PracticeSummaryView extends StatelessWidget {
  const PracticeSummaryView({
    required this.correctFirstTry,
    required this.total,
    required this.onPracticeMore,
    required this.onBack,
    required this.onBackToTopic,
    super.key,
  });

  final int correctFirstTry;
  final int total;
  final VoidCallback onPracticeMore;
  final VoidCallback onBack;
  final VoidCallback onBackToTopic;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpace.s4,
        children: [
          const AppIllustration(AppIllustrationName.practiceDone),
          Text(
            PracticeCopy.summaryTitle,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          Container(
            padding: const EdgeInsets.all(AppSpace.s6),
            decoration: BoxDecoration(
              color: context.appColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: context.appColors.line),
            ),
            child: Column(
              spacing: AppSpace.s2,
              children: [
                Text(
                  '$correctFirstTry / $total',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontFeatures: AppType.count.fontFeatures,
                  ),
                ),
                Text(
                  PracticeCopy.summaryBody(correctFirstTry, total),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: context.appColors.inkSecondary,
                  ),
                ),
              ],
            ),
          ),
          LoadingButton(
            label: PracticeCopy.moreButton,
            expanded: true,
            onPressed: onPracticeMore,
          ),
          _SecondaryActions(onBack: onBack, onBackToTopic: onBackToTopic),
        ],
      ),
    ),
  );
}

class _SecondaryActions extends StatelessWidget {
  const _SecondaryActions({required this.onBack, required this.onBackToTopic});

  final VoidCallback onBack;
  final VoidCallback onBackToTopic;

  @override
  Widget build(BuildContext context) {
    final topic = LoadingButton(
      label: LearningCopy.backToTopic,
      onPressed: onBackToTopic,
      expanded: true,
      variant: AppButtonVariant.secondary,
    );
    final course = LoadingButton(
      label: PracticeCopy.backButton,
      onPressed: onBack,
      expanded: true,
      variant: AppButtonVariant.secondary,
    );
    return MediaQuery.sizeOf(context).width < 600
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: AppSpace.s4,
            children: [topic, course],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: AppSpace.s4,
            children: [
              Expanded(child: topic),
              Expanded(child: course),
            ],
          );
  }
}
