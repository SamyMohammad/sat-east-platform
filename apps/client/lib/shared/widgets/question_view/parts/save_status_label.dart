import 'package:flutter/material.dart';

import 'package:sat_east_client/core/theme/app_icons.dart';
import 'package:sat_east_client/core/theme/app_tokens.dart';
import 'package:sat_east_client/shared/widgets/question_view/question_view_mode.dart';

/// Homework autosave state: icon + copy, announced as a live region.
class SaveStatusLabel extends StatelessWidget {
  const SaveStatusLabel({required this.status, super.key, this.onRetry});

  final SaveStatus status;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = status == SaveStatus.failed
        ? scheme.error
        : scheme.onSurfaceVariant;
    final style = theme.textTheme.labelSmall?.copyWith(color: color);
    final (icon, copy) = switch (status) {
      SaveStatus.saving => (null, 'Saving…'),
      SaveStatus.saved => (AppIcons.saved, 'Saved'),
      SaveStatus.offline => (AppIcons.unsynced, 'Offline — will sync'),
      SaveStatus.failed => (AppIcons.error, "Couldn't save"),
    };
    return Semantics(
      liveRegion: true,
      container: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon == null)
            SizedBox.square(
              dimension: AppSize.iconStatus,
              child: CircularProgressIndicator(
                strokeWidth: AppStroke.strong,
                color: color,
              ),
            )
          else
            Icon(icon, size: AppSize.iconStatus, color: color),
          const SizedBox(width: AppSpace.s2),
          Flexible(
            child: Text(
              copy,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          ),
          if (status == SaveStatus.failed)
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                minimumSize: const Size(0, AppSize.touchTarget),
              ),
              child: const Text('Retry'),
            ),
        ],
      ),
    );
  }
}
