// Feature-local imports follow the project convention.
// ignore_for_file: always_use_package_imports

import 'package:flutter/material.dart';

import 'package:sat_east_client/core/theme/app_colors.dart';
import 'package:sat_east_client/core/theme/app_tokens.dart';
import 'package:sat_east_client/core/theme/app_type.dart';
import 'package:sat_east_client/shared/widgets/growing_bar.dart';

import '../../domain/entities/quiz.dart';
import '../quiz_copy.dart';

class QuizResultSkills extends StatelessWidget {
  const QuizResultSkills({required this.skills, super.key});

  final List<QuizSkillResult> skills;

  @override
  Widget build(BuildContext context) {
    if (skills.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpace.s4,
      children: [
        Text(QuizCopy.bySkill, style: Theme.of(context).textTheme.titleMedium),
        for (final (index, skill) in skills.indexed)
          Semantics(
            label: QuizCopy.skillResult(skill.name, skill.correct, skill.total),
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
                        QuizCopy.skillCount(skill.correct, skill.total),
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
