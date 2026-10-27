import 'package:flutter/material.dart';

import 'package:sat_east_client/core/theme/app_colors.dart';
import 'package:sat_east_client/core/theme/app_tokens.dart';
import 'package:sat_east_client/shared/widgets/app_illustration.dart';

class AppStatusFrame extends StatelessWidget {
  const AppStatusFrame({
    required this.icon,
    required this.title,
    required this.message,
    super.key,
    this.iconColor,
    this.illustration,
    this.actions = const [],
  });

  final IconData icon;
  final String title;
  final String message;
  final Color? iconColor;
  final AppIllustrationName? illustration;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpace.s6),
      decoration: BoxDecoration(
        color: context.appColors.surface,
        border: Border.all(color: context.appColors.line),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (illustration case final name?)
            AppIllustration(name)
          else
            ExcludeSemantics(
              child: Icon(
                icon,
                size: AppSize.statusIcon,
                color: iconColor ?? context.appColors.inkSecondary,
              ),
            ),
          const SizedBox(height: AppSpace.s3),
          Text(title, style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpace.s3),
          Text(
            message,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: context.appColors.inkSecondary,
            ),
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: AppSpace.s4),
            Wrap(
              spacing: AppSpace.s2,
              runSpacing: AppSpace.s2,
              children: actions,
            ),
          ],
        ],
      ),
    );
  }
}
