import 'package:flutter/material.dart';

import 'package:sat_east_client/core/theme/app_colors.dart';
import 'package:sat_east_client/core/theme/app_tokens.dart';
import 'package:sat_east_client/core/theme/app_type.dart';
import 'package:sat_east_client/features/skills/domain/entities/skills_overview.dart';
import 'package:sat_east_client/features/skills/presentation/skills_copy.dart';
import 'package:sat_east_client/features/skills/presentation/widgets/mastery_band_chip.dart';
import 'package:sat_east_client/shared/widgets/growing_bar.dart';

/// One skill: name, mastery bar 0-100 in the band colour, the number and the
/// band word.
class SkillBarRow extends StatelessWidget {
  const SkillBarRow({required this.skill, required this.index, super.key});

  final SkillMastery skill;
  final int index;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final mastery = skill.mastery;
    return Semantics(
      container: true,
      label: [
        skill.name,
        if (mastery != null) '${SkillsCopy.mastery(mastery)} of 100',
        SkillsCopy.band(skill.band),
      ].join(', '),
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpace.s2),
          child: Column(
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
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: MasteryBandChip(skill.band),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
