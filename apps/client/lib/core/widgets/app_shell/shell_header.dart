import 'package:flutter/material.dart';

import 'package:sat_east_client/core/theme/booklet_tokens.dart';
import 'package:sat_east_client/core/widgets/app_shell/app_shell_destination.dart';

class ShellHeader extends StatelessWidget {
  const ShellHeader({
    required this.layout,
    required this.destination,
    super.key,
    this.onNotifications,
  });

  final BookletLayout layout;
  final AppShellDestination destination;
  final VoidCallback? onNotifications;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (height, margin) = switch (layout) {
      BookletLayout.compact => (
        BookletSize.shellCompactHeader,
        BookletSpace.s4,
      ),
      BookletLayout.medium => (
        BookletSize.shellMediumHeader,
        BookletSpace.s6,
      ),
      BookletLayout.expanded => (
        BookletSize.shellExpandedHeader,
        BookletSpace.s8,
      ),
    };
    final verticalPadding = layout == BookletLayout.compact
        ? BookletSpace.s1
        : BookletSpace.s2;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant,
          ),
        ),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: height),
        child: Padding(
          padding: EdgeInsetsDirectional.fromSTEB(
            margin,
            verticalPadding,
            BookletSpace.s1,
            verticalPadding,
          ),
          child: Row(
            children: [
              if (layout == BookletLayout.compact) ...[
                const ShellMonogram(compact: true),
                const SizedBox(width: BookletSpace.s3),
              ],
              Expanded(
                child: Text(
                  destination.label,
                  style: layout == BookletLayout.expanded
                      ? theme.textTheme.headlineSmall
                      : theme.textTheme.titleLarge,
                ),
              ),
              IconButton(
                tooltip: 'Notifications',
                onPressed: onNotifications,
                icon: const Icon(Icons.notifications_outlined),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ShellMonogram extends StatelessWidget {
  const ShellMonogram({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = compact
        ? BookletSize.shellCompactMonogram
        : BookletSize.shellMonogram;
    return ExcludeSemantics(
      child: Container(
        constraints: BoxConstraints(minWidth: size, minHeight: size),
        padding: const EdgeInsets.all(BookletSpace.s1),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary,
          borderRadius: BorderRadius.circular(BookletRadius.sm),
        ),
        child: Center(
          widthFactor: 1,
          heightFactor: 1,
          child: Text(
            'AE',
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class ShellWordmark extends StatelessWidget {
  const ShellWordmark({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(BookletSpace.s6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: 'Abdelrahman '),
                TextSpan(
                  text: 'Elmenshawy',
                  style: TextStyle(
                    decoration: TextDecoration.underline,
                    decorationColor: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: BookletSpace.s2),
          Text(
            'SAT & EST Math',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
