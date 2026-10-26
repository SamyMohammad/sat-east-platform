import 'package:flutter/material.dart';

import 'package:sat_east_client/core/theme/app_icons.dart';
import 'package:sat_east_client/core/theme/booklet_tokens.dart';
import 'package:sat_east_client/shared/widgets/app_chip.dart';
import 'package:sat_east_client/shared/widgets/question_view/question_data.dart';

/// "4.2 · EX 7" label with optional difficulty and skill chips.
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
    final scheme = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: scheme.outlineVariant,
            // Explicit: keeps the 1 px rule if the default changes.
            // ignore: avoid_redundant_argument_values
            width: BookletStroke.thin,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: BookletSpace.s3),
        child: SizedBox(
          width: double.infinity,
          child: Wrap(
            spacing: BookletSpace.s2,
            runSpacing: BookletSpace.s2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                label.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              if (difficulty != null)
                AppChip(
                  kind: AppChipKind.difficulty,
                  label: _difficultyCopy(difficulty!),
                ),
              if (skill != null)
                AppChip(
                  icon: AppIcons.topic,
                  label: skill!,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
