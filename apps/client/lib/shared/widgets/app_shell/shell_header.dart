import 'package:flutter/material.dart';
import 'package:sat_east_client/core/theme/app_icons.dart';
import 'package:sat_east_client/core/theme/app_tokens.dart';
import 'package:sat_east_client/shared/widgets/app_shell/app_shell_destination.dart';
import 'package:sat_east_client/shared/widgets/brand_mark.dart';

class ShellHeader extends StatelessWidget {
  const ShellHeader({
    required this.layout,
    required this.destination,
    super.key,
    this.onNotifications,
  });

  final AppLayout layout;
  final AppShellDestination destination;
  final VoidCallback? onNotifications;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (height, margin) = switch (layout) {
      AppLayout.compact => (
        AppSize.shellCompactHeader,
        AppSpace.s4,
      ),
      AppLayout.medium => (
        AppSize.shellMediumHeader,
        AppSpace.s6,
      ),
      AppLayout.expanded => (
        AppSize.shellExpandedHeader,
        AppSpace.s8,
      ),
    };
    final verticalPadding = layout == AppLayout.compact
        ? AppSpace.s1
        : AppSpace.s2;
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
            AppSpace.s1,
            verticalPadding,
          ),
          child: Row(
            children: [
              if (layout == AppLayout.compact) ...[
                const ShellMonogram(compact: true),
                const SizedBox(width: AppSpace.s3),
              ],
              Expanded(
                child: Text(
                  destination.label,
                  style: layout == AppLayout.expanded
                      ? theme.textTheme.headlineSmall
                      : theme.textTheme.titleLarge,
                ),
              ),
              IconButton(
                tooltip: 'Notifications',
                onPressed: onNotifications,
                icon: const Icon(AppIcons.notifications),
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
    final size = compact ? AppSize.shellCompactMonogram : AppSize.shellMonogram;
    return ExcludeSemantics(
      child: Container(
        constraints: BoxConstraints(minWidth: size, minHeight: size),
        padding: const EdgeInsets.all(AppSpace.s1),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary,
          borderRadius: BorderRadius.circular(AppRadius.control),
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
  const ShellWordmark({
    super.key,
    this.padding = const EdgeInsets.all(AppSpace.s6),
  });

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: padding,
      child: Row(
        children: [
          const BrandMark(),
          const SizedBox(width: AppSpace.s2),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Abdelrahman Elmenshawy',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpace.s2),
                Text(
                  'SAT & EST Math',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
