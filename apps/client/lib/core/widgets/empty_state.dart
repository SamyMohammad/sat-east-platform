import 'package:flutter/material.dart';

import 'package:sat_east_client/core/widgets/booklet_status_frame.dart';
import 'package:sat_east_client/core/widgets/loading_button.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.title,
    required this.message,
    super.key,
    this.icon = Icons.quiz_outlined,
    this.actionLabel,
    this.onAction,
  }) : assert(
         (actionLabel == null) == (onAction == null),
         'Provide both actionLabel and onAction, or neither.',
       );

  final String title;
  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => BookletStatusFrame(
    icon: icon,
    title: title,
    message: message,
    actions: [
      if (actionLabel != null && onAction != null)
        LoadingButton(
          label: actionLabel!,
          onPressed: onAction,
          variant: BookletButtonVariant.secondary,
        ),
    ],
  );
}
