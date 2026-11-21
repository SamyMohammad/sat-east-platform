import 'package:flutter/material.dart';

import 'package:sat_east_client/core/theme/app_colors.dart';
import 'package:sat_east_client/core/theme/app_tokens.dart';
import 'package:sat_east_client/core/theme/app_type.dart';
import 'package:sat_east_client/features/skills/domain/entities/skills_overview.dart';
import 'package:sat_east_client/features/skills/presentation/skills_copy.dart';
import 'package:sat_east_client/features/skills/presentation/skills_layout.dart';
import 'package:sat_east_client/features/skills/presentation/widgets/mastery_band_chip.dart';
import 'package:sat_east_client/features/skills/presentation/widgets/skill_sparkline.dart';
import 'package:sat_east_client/shared/widgets/growing_bar.dart';

/// One skill: name, mastery bar 0-100 in the band colour, the number, the
/// band word, accuracy and speed, and a weekly sparkline with its change once
/// there are two weeks of history.
class SkillBarRow extends StatelessWidget {
  const SkillBarRow({required this.skill, required this.index, super.key});

  final SkillMastery skill;
  final int index;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final mastery = skill.mastery;
    final stats = SkillsCopy.accuracyLine(skill);
    final delta = skill.history.spanDelta;
    return Semantics(
      container: true,
      label: [
        skill.name,
        if (mastery != null) '${SkillsCopy.mastery(mastery)} of 100',
        SkillsCopy.band(skill.band),
        ?stats,
        if (delta != null)
          SkillsCopy.sparkDeltaSpoken(
            delta,
            since: skill.history.first.weekStart,
          ),
      ].join(', '),
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpace.s2),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < SkillsLayout.narrowWidth;
              final mini = SkillTrendMini(history: skill.history);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: AppSpace.s2,
                children: [
                  Text(
                    skill.name,
                    style: theme.textTheme.bodyMedium,
                    textDirection: TextDirection.ltr,
                  ),
                  Row(
                    spacing: AppSpace.s3,
                    children: [
                      Expanded(
                        child: GrowingBar(
                          value: (mastery ?? 0) / 100,
                          color: skill.band.color(colors),
                          index: index,
                        ),
                      ),
                      if (delta != null && !narrow) mini,
                      SizedBox(
                        width: AppSpace.s8,
                        child: Text(
                          mastery == null ? '–' : SkillsCopy.mastery(mastery),
                          textAlign: TextAlign.end,
                          style: AppType.count.copyWith(color: colors.ink),
                        ),
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: AppSpace.s3,
                    runSpacing: AppSpace.s2,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      MasteryBandChip(skill.band),
                      if (stats != null)
                        Text(
                          stats,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.inkSecondary,
                          ),
                        ),
                      if (delta != null && narrow) mini,
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
