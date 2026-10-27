import 'package:flutter/material.dart';

import 'package:sat_east_client/core/theme/app_tokens.dart';

/// Icon + short status text ("Correct", "Your answer"), Components.dc.html.
class FeedbackLabel extends StatelessWidget {
  const FeedbackLabel({
    required this.icon,
    required this.label,
    required this.color,
    super.key,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: AppSpace.s1,
      children: [
        Icon(icon, size: AppSize.iconStatus, color: color),
        Flexible(
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: color, letterSpacing: 0),
          ),
        ),
      ],
    );
  }
}
