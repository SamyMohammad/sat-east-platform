import 'package:flutter/material.dart';

import 'package:sat_east_client/features/practice/presentation/practice_copy.dart';
import 'package:sat_east_client/shared/widgets/booklet_status_frame.dart';
import 'package:sat_east_client/shared/widgets/loading_button.dart';

class PracticeSummaryView extends StatelessWidget {
  const PracticeSummaryView({
    required this.correctFirstTry,
    required this.total,
    required this.onPracticeMore,
    required this.onBack,
    super.key,
  });

  final int correctFirstTry;
  final int total;
  final VoidCallback onPracticeMore;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => BookletStatusFrame(
    icon: Icons.task_alt,
    title: PracticeCopy.summaryTitle,
    message: PracticeCopy.summaryBody(correctFirstTry, total),
    actions: [
      LoadingButton(label: PracticeCopy.moreButton, onPressed: onPracticeMore),
      LoadingButton(
        label: PracticeCopy.backButton,
        onPressed: onBack,
        variant: BookletButtonVariant.secondary,
      ),
    ],
  );
}
