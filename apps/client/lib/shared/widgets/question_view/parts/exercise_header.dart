import 'package:flutter/material.dart';

import 'package:sat_east_client/core/theme/app_colors.dart';
import 'package:sat_east_client/core/theme/app_tokens.dart';
import 'package:sat_east_client/shared/widgets/app_chip.dart';
import 'package:sat_east_client/shared/widgets/question_view/question_data.dart';

/// Quiet skill line with an optional difficulty pill.
class ExerciseHeader extends StatelessWidget {
  const ExerciseHeader({
    required this.label,
    super.key,
    this.difficulty,
    this.skill,
  });

  final String label;
  final QuestionDifficulty? difficulty;
  final String? skill;

  static String _difficultyCopy(QuestionDifficulty d) => switch (d) {
    QuestionDifficulty.easy => 'E · Easy',
    QuestionDifficulty.medium => 'M · Medium',
    QuestionDifficulty.hard => 'H · Hard',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: AppSpace.s2,
      runSpacing: AppSpace.s2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          skill ?? label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: context.appColors.inkSecondary,
          ),
        ),
        if (difficulty != null)
          AppChip(
            kind: AppChipKind.difficulty,
            label: _difficultyCopy(difficulty!),
          ),
      ],
    );
  }
}
