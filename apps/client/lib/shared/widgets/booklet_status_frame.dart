import 'package:flutter/material.dart';

import 'package:sat_east_client/core/theme/booklet_tokens.dart';

class BookletStatusFrame extends StatelessWidget {
  const BookletStatusFrame({
    required this.icon,
    required this.title,
    required this.message,
    super.key,
    this.iconColor,
    this.actions = const [],
  });

  final IconData icon;
  final String title;
  final String message;
  final Color? iconColor;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: BookletSpace.s8),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: theme.colorScheme.outline),
          bottom: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: Icon(
              icon,
              size: BookletSize.statusIcon,
              color: iconColor ?? theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: BookletSpace.s3),
          Text(title, style: theme.textTheme.titleLarge),
          const SizedBox(height: BookletSpace.s3),
          Text(
            message,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: BookletSpace.s4),
            Wrap(
              spacing: BookletSpace.s2,
              runSpacing: BookletSpace.s2,
              children: actions,
            ),
          ],
        ],
      ),
    );
  }
}
