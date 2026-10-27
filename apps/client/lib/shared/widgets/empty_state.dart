import 'package:flutter/material.dart';

import 'package:sat_east_client/core/theme/app_icons.dart';
import 'package:sat_east_client/shared/widgets/app_illustration.dart';
import 'package:sat_east_client/shared/widgets/app_status_frame.dart';
import 'package:sat_east_client/shared/widgets/loading_button.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.title,
    required this.message,
    super.key,
    this.illustration,
    this.icon = AppIcons.quiz,
    this.actionLabel,
    this.onAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
  }) : assert(
         (actionLabel == null) == (onAction == null),
         'Provide both actionLabel and onAction, or neither.',
       ),
       assert(
         (secondaryActionLabel == null) == (onSecondaryAction == null),
         'Provide both secondaryActionLabel and onSecondaryAction, or neither.',
       );

  final AppIllustrationName? illustration;
  final String title;
  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;

  @override
  Widget build(BuildContext context) => AppStatusFrame(
    icon: icon,
    illustration: illustration,
    title: title,
    message: message,
    actions: [
      if (actionLabel != null || secondaryActionLabel != null)
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (actionLabel != null && onAction != null)
              LoadingButton(
                label: actionLabel!,
                onPressed: onAction,
                variant: AppButtonVariant.secondary,
              ),
            if (secondaryActionLabel != null && onSecondaryAction != null)
              TextButton(
                onPressed: onSecondaryAction,
                child: Text(secondaryActionLabel!),
              ),
          ],
        ),
    ],
  );
}
