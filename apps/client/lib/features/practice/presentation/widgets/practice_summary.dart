import 'package:flutter/material.dart';

import 'package:sat_east_client/core/presentation/learning_copy.dart';
import 'package:sat_east_client/core/theme/app_icons.dart';
import 'package:sat_east_client/features/practice/presentation/practice_copy.dart';
import 'package:sat_east_client/shared/widgets/app_status_frame.dart';
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
  Widget build(BuildContext context) => AppStatusFrame(
    icon: AppIcons.completed,
    title: PracticeCopy.summaryTitle,
    message: PracticeCopy.summaryBody(correctFirstTry, total),
    actions: [
      LoadingButton(label: PracticeCopy.moreButton, onPressed: onPracticeMore),
      LoadingButton(
        label: LearningCopy.backToTopic,
        onPressed: onBackToTopic,
        variant: AppButtonVariant.secondary,
      ),
      LoadingButton(
        label: PracticeCopy.backButton,
        onPressed: onBack,
        variant: AppButtonVariant.secondary,
      ),
    ],
  );
}
