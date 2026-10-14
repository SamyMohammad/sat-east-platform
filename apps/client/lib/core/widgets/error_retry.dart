import 'package:flutter/material.dart';

import 'package:sat_east_client/core/widgets/booklet_status_frame.dart';
import 'package:sat_east_client/core/widgets/loading_button.dart';

class ErrorRetry extends StatelessWidget {
  const ErrorRetry({
    required this.title,
    required this.message,
    required this.onRetry,
    super.key,
    this.isRetrying = false,
    this.secondaryLabel,
    this.onSecondary,
  }) : assert(
         (secondaryLabel == null) == (onSecondary == null),
         'Provide both secondaryLabel and onSecondary, or neither.',
       );

  final String title;
  final String message;
  final VoidCallback onRetry;
  final bool isRetrying;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) => BookletStatusFrame(
    icon: Icons.wifi_off,
    iconColor: Theme.of(context).colorScheme.onSurface,
    title: title,
    message: message,
    actions: [
      LoadingButton(
        label: 'Retry',
        icon: Icons.refresh,
        onPressed: onRetry,
        isLoading: isRetrying,
      ),
      if (secondaryLabel != null && onSecondary != null)
        LoadingButton(
          label: secondaryLabel!,
          onPressed: onSecondary,
          variant: BookletButtonVariant.tertiary,
        ),
    ],
  );
}
