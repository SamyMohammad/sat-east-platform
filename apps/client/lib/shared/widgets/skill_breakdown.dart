import 'package:flutter/material.dart';

import 'package:sat_east_client/core/attempts/skill_result.dart';
import 'package:sat_east_client/core/theme/app_colors.dart';
import 'package:sat_east_client/core/theme/app_tokens.dart';
import 'package:sat_east_client/core/theme/app_type.dart';
import 'package:sat_east_client/shared/widgets/growing_bar.dart';

const _bySkill = 'By skill';

String _skillCount(int correct, int total) => '$correct of $total';

String _skillResult(String name, int correct, int total) =>
    '$name, ${_skillCount(correct, total)} correct';

class SkillBreakdown extends StatelessWidget {
  const SkillBreakdown({required this.skills, super.key});

  final List<SkillResult> skills;

  @override
  Widget build(BuildContext context) {
    if (skills.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpace.s4,
      children: [
        Text(_bySkill, style: Theme.of(context).textTheme.titleMedium),
        for (final (index, skill) in skills.indexed)
          Semantics(
            container: true,
            label: _skillResult(skill.name, skill.correct, skill.total),
            child: ExcludeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: AppSpace.s2,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: Text(skill.name)),
                      const SizedBox(width: AppSpace.s3),
                      Text(
                        _skillCount(skill.correct, skill.total),
                        style: AppType.count,
                      ),
                    ],
                  ),
                  GrowingBar(
                    value: skill.total > 0 ? skill.correct / skill.total : 0,
                    color: context.appColors.brand,
                    index: index,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
