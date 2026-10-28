import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:sat_east_client/core/router/app_router.dart';
import 'package:sat_east_client/core/theme/app_colors.dart';
import 'package:sat_east_client/core/theme/app_tokens.dart';
import 'package:sat_east_client/features/skills/domain/entities/skills_overview.dart';
import 'package:sat_east_client/features/skills/presentation/skills_copy.dart';
import 'package:sat_east_client/features/skills/presentation/widgets/mastery_band_chip.dart';
import 'package:sat_east_client/shared/widgets/loading_button.dart';

/// Up to three weakest skills, each with a one-tap way to practise.
class WeakSkillsSection extends StatelessWidget {
  const WeakSkillsSection({required this.weak, super.key});

  final List<WeakSkill> weak;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpace.s3,
      children: [
        Semantics(
          header: true,
          child: Text(SkillsCopy.weakTitle, style: theme.textTheme.titleMedium),
        ),
        if (weak.isEmpty)
          Text(
            SkillsCopy.weakThin,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.inkSecondary,
            ),
          ),
        for (final skill in weak)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.s4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: AppSpace.s2,
                children: [
                  Row(
                    spacing: AppSpace.s3,
                    children: [
                      Expanded(
                        child: Text(
                          skill.name,
                          style: theme.textTheme.titleSmall,
                          textDirection: TextDirection.ltr,
                        ),
                      ),
                      Text(
                        SkillsCopy.mastery(skill.mastery),
                        style: theme.textTheme.titleMedium,
                      ),
                    ],
                  ),
                  const MasteryBandChip(MasteryBand.weak),
                  Text(
                    skill.topicTitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.inkSecondary,
                    ),
                    textDirection: TextDirection.ltr,
                  ),
                  LoadingButton(
                    label: SkillsCopy.practise,
                    variant: AppButtonVariant.secondary,
                    onPressed: () => context.go(AppRoutes.topic(skill.topicId)),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
