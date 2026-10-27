import 'package:flutter/material.dart';

import 'package:sat_east_client/core/theme/app_hues.dart';
import 'package:sat_east_client/core/theme/app_icons.dart';
import 'package:sat_east_client/core/theme/app_tokens.dart';
import 'package:sat_east_client/features/catalogue/domain/entities/course_unit.dart';
import 'package:sat_east_client/features/catalogue/presentation/catalogue_copy.dart';
import 'package:sat_east_client/shared/widgets/icon_tile.dart';

class SyllabusUnit extends StatelessWidget {
  const SyllabusUnit({required this.unit, required this.number, super.key});

  final CourseUnit unit;
  final int number;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpace.s3,
      children: [
        Semantics(
          header: true,
          child: Container(
            padding: const EdgeInsets.all(AppSpace.s4),
            decoration: BoxDecoration(
              color: SubjectHue.forIndex(number - 1).wash(theme.brightness),
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            child: Text(
              unit.title,
              style: theme.textTheme.titleLarge,
              textDirection: TextDirection.ltr,
            ),
          ),
        ),
        for (final (index, topic) in unit.topics.indexed)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpace.s2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: AppSpace.s3,
              children: [
                IconTile(AppIcons.topic, hue: SubjectHue.forIndex(number - 1)),
                Text('$number.${index + 1}', style: theme.textTheme.labelLarge),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: AppSpace.s2,
                    children: [
                      Text(
                        topic.title,
                        textDirection: TextDirection.ltr,
                      ),
                      Wrap(
                        spacing: AppSpace.s3,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            CatalogueCopy.subtopics(topic.subtopicCount),
                            style: theme.textTheme.bodySmall,
                          ),
                          if (topic.isFreePreview)
                            const Chip(label: Text(CatalogueCopy.free)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
