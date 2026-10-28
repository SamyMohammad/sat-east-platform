import 'package:flutter/material.dart';

import 'package:sat_east_client/core/theme/app_colors.dart';
import 'package:sat_east_client/core/theme/app_tokens.dart';
import 'package:sat_east_client/features/skills/domain/entities/skills_overview.dart';
import 'package:sat_east_client/features/skills/presentation/skills_copy.dart';
import 'package:sat_east_client/features/skills/presentation/widgets/mastery_band_chip.dart';

/// One topic: title, "X of Y solved" and its level chip.
class TopicLevelRow extends StatelessWidget {
  const TopicLevelRow({required this.topic, super.key});

  final TopicLevel topic;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.s2),
      child: Row(
        spacing: AppSpace.s3,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  topic.title,
                  style: theme.textTheme.titleSmall,
                  textDirection: TextDirection.ltr,
                ),
                Text(
                  SkillsCopy.topicSolved(topic.solved, topic.total),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: context.appColors.inkSecondary,
                  ),
                ),
              ],
            ),
          ),
          Flexible(child: MasteryBandChip(topic.level)),
        ],
      ),
    );
  }
}
