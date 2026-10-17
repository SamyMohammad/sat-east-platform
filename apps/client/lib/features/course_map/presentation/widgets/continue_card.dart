import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sat_east_client/core/router/app_router.dart';
import 'package:sat_east_client/core/text/text_direction.dart';
import 'package:sat_east_client/core/theme/booklet_tokens.dart';
import 'package:sat_east_client/features/course_map/domain/entities/course_map.dart';
import 'package:sat_east_client/features/course_map/presentation/course_map_copy.dart';
import 'package:sat_east_client/shared/widgets/loading_button.dart';

class ContinueCard extends StatelessWidget {
  const ContinueCard({required this.topic, super.key});

  final ContinueTopic topic;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final unitTitle = topic.unitTitle;
    return Container(
      padding: const EdgeInsets.all(BookletSpace.s4),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        border: Border.all(color: scheme.primary, width: BookletStroke.strong),
        borderRadius: BorderRadius.circular(BookletRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            CourseMapCopy.continueEyebrow,
            style: theme.textTheme.labelSmall?.copyWith(color: scheme.primary),
          ),
          const SizedBox(height: BookletSpace.s1),
          Text(
            topic.title,
            style: theme.textTheme.titleMedium,
            textDirection: detectTextDirection(topic.title),
          ),
          if (unitTitle != null)
            Text(
              unitTitle,
              style: theme.textTheme.bodySmall,
              textDirection: detectTextDirection(unitTitle),
            ),
          const SizedBox(height: BookletSpace.s3),
          LoadingButton(
            label: CourseMapCopy.continueButton,
            icon: Icons.arrow_forward,
            onPressed: () =>
                context.go(AppRoutes.topic(topic.topicId), extra: topic.title),
          ),
        ],
      ),
    );
  }
}
