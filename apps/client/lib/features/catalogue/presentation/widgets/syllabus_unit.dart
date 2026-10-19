import 'package:flutter/material.dart';
import 'package:sat_east_client/core/text/text_direction.dart';
import 'package:sat_east_client/core/theme/booklet_tokens.dart';
import 'package:sat_east_client/features/catalogue/domain/entities/course_unit.dart';
import 'package:sat_east_client/features/catalogue/presentation/catalogue_copy.dart';

class SyllabusUnit extends StatelessWidget {
  const SyllabusUnit({required this.unit, required this.number, super.key});

  final CourseUnit unit;
  final int number;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: BookletSpace.s3,
      children: [
        Semantics(
          header: true,
          child: Text(
            unit.title,
            style: theme.textTheme.titleLarge,
            textDirection: detectTextDirection(unit.title),
          ),
        ),
        for (final (index, topic) in unit.topics.indexed)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: BookletSpace.s2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: BookletSpace.s3,
              children: [
                Text('$number.${index + 1}', style: theme.textTheme.labelLarge),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: BookletSpace.s2,
                    children: [
                      Text(
                        topic.title,
                        textDirection: detectTextDirection(topic.title),
                      ),
                      Wrap(
                        spacing: BookletSpace.s3,
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
