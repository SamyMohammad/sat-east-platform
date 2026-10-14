import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:sat_east_client/core/theme/booklet_tokens.dart';
import 'package:sat_east_client/core/widgets/app_shell/app_shell_destination.dart';
import 'package:sat_east_client/core/widgets/app_shell/shell_navigation_metrics.dart';

class ShellBottomNavigation extends StatelessWidget {
  const ShellBottomNavigation({
    required this.selectedIndex,
    required this.onDestinationSelected,
    super.key,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  static const _indicator = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(BookletRadius.sm)),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scaler = MediaQuery.textScalerOf(context);
    final label = theme.textTheme.labelSmall!;
    final scaledLabel = label.copyWith(
      fontSize: scaler.scale(label.fontSize!),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outlineVariant,
          ),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final labelWidth =
              constraints.maxWidth / AppShellDestination.values.length -
              BookletSpace.s2;
          final labelHeight = maxShellLabelHeight(
            context,
            scaledLabel,
            labelWidth,
            TextScaler.noScaling,
          );
          // NavigationDestination clamps scaling internally. Pre-scale only its
          // labels to preserve the user's full, potentially nonlinear scale.
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.noScaling,
            ),
            child: NavigationBar(
              selectedIndex: selectedIndex,
              onDestinationSelected: onDestinationSelected,
              height: math.max(
                BookletSize.shellNavigation,
                BookletSize.chipVisual + labelHeight + BookletSpace.s4,
              ),
              backgroundColor: theme.colorScheme.surface,
              elevation: 0,
              indicatorColor: theme.colorScheme.primaryContainer,
              indicatorShape: _indicator,
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              labelTextStyle: WidgetStateProperty.resolveWith(
                (states) => scaledLabel.copyWith(
                  fontWeight: states.contains(WidgetState.selected)
                      ? FontWeight.w700
                      : FontWeight.w500,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              labelPadding: const EdgeInsetsDirectional.only(
                top: BookletSpace.s1,
                start: BookletSpace.s1,
                end: BookletSpace.s1,
              ),
              destinations: [
                for (final destination in AppShellDestination.values)
                  NavigationDestination(
                    icon: Icon(destination.icon),
                    selectedIcon: Icon(
                      destination.selectedIcon,
                      color: theme.colorScheme.primary,
                    ),
                    label: destination.label,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
