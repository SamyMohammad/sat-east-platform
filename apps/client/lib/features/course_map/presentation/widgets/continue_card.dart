import 'package:flutter/material.dart';

import 'package:go_router/go_router.dart';

import 'package:sat_east_client/core/router/app_router.dart';
import 'package:sat_east_client/core/theme/app_icons.dart';
import 'package:sat_east_client/core/theme/app_tokens.dart';
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
      padding: const EdgeInsets.all(AppSpace.s4),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        border: Border.all(color: scheme.primary, width: AppStroke.strong),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            CourseMapCopy.continueEyebrow,
            style: theme.textTheme.labelSmall?.copyWith(color: scheme.primary),
          ),
          const SizedBox(height: AppSpace.s1),
          Text(
            topic.title,
            style: theme.textTheme.titleMedium,
            textDirection: TextDirection.ltr,
          ),
          if (unitTitle != null)
            Text(
              unitTitle,
              style: theme.textTheme.bodySmall,
              textDirection: TextDirection.ltr,
            ),
          const SizedBox(height: AppSpace.s3),
          LoadingButton(
            label: CourseMapCopy.continueButton,
            icon: AppIcons.forward,
            onPressed: () =>
                context.go(AppRoutes.topic(topic.topicId), extra: topic.title),
          ),
        ],
      ),
    );
  }
}
