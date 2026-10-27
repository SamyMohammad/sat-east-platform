import 'package:flutter/material.dart';

import 'package:sat_east_client/core/theme/app_colors.dart';

import 'package:sat_east_client/core/theme/app_icons.dart';
import 'package:sat_east_client/shared/widgets/app_illustration.dart';
import 'package:sat_east_client/shared/widgets/app_status_frame.dart';
import 'package:sat_east_client/shared/widgets/loading_button.dart';

class ErrorRetry extends StatelessWidget {
  const ErrorRetry({
    required this.title,
    required this.message,
    required this.onRetry,
    super.key,
    this.illustration = AppIllustrationName.offline,
    this.isRetrying = false,
    this.secondaryLabel,
    this.onSecondary,
  }) : assert(
         (secondaryLabel == null) == (onSecondary == null),
         'Provide both secondaryLabel and onSecondary, or neither.',
       );

  final AppIllustrationName? illustration;
  final String title;
  final String message;
  final VoidCallback onRetry;
  final bool isRetrying;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) => AppStatusFrame(
    icon: AppIcons.offline,
    iconColor: context.appColors.ink,
    illustration: illustration,
    title: title,
    message: message,
    actions: [
      LoadingButton(
        label: 'Retry',
        icon: AppIcons.retry,
        onPressed: onRetry,
        isLoading: isRetrying,
      ),
      if (secondaryLabel != null && onSecondary != null)
        LoadingButton(
          label: secondaryLabel!,
          onPressed: onSecondary,
          variant: AppButtonVariant.tertiary,
        ),
    ],
  );
}
