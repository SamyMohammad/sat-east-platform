import 'package:flutter/material.dart';

import 'package:sat_east_client/core/theme/app_colors.dart';
import 'package:sat_east_client/core/theme/app_tokens.dart';
import 'package:sat_east_client/features/skills/domain/entities/skills_overview.dart';
import 'package:sat_east_client/features/skills/presentation/skills_copy.dart';
import 'package:sat_east_client/shared/widgets/growing_bar.dart';

/// "X of Y questions solved" with a thin progress bar and the answer count.
class SkillsSummaryCard extends StatelessWidget {
  const SkillsSummaryCard({required this.summary, super.key});

  final SkillsSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpace.s3,
          children: [
            Text(
              SkillsCopy.solved(summary.solved, summary.total),
              style: theme.textTheme.titleMedium,
            ),
            GrowingBar(
              value: summary.total == 0 ? 0 : summary.solved / summary.total,
              color: colors.brand,
            ),
            Text(
              SkillsCopy.answers(summary.gradedAnswers),
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.inkSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
