import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:sat_east_client/core/theme/booklet_tokens.dart';
import 'package:sat_east_client/core/widgets/app_shell/app_shell_destination.dart';
import 'package:sat_east_client/core/widgets/app_shell/shell_bottom_navigation.dart';
import 'package:sat_east_client/core/widgets/app_shell/shell_header.dart';
import 'package:sat_east_client/core/widgets/app_shell/shell_navigation_metrics.dart';

class ShellNavigation extends StatelessWidget {
  const ShellNavigation({
    required this.layout,
    required this.selectedIndex,
    required this.onDestinationSelected,
    super.key,
  });

  final BookletLayout layout;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  static const _indicator = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(BookletRadius.sm)),
  );

  @override
  Widget build(BuildContext context) => switch (layout) {
    BookletLayout.compact => ShellBottomNavigation(
      selectedIndex: selectedIndex,
      onDestinationSelected: onDestinationSelected,
    ),
    BookletLayout.medium => _rail(context),
    BookletLayout.expanded => _drawer(context),
  };

  Widget _rail(BuildContext context) {
    final theme = Theme.of(context);
    final label = theme.textTheme.labelSmall!;
    final scale =
        MediaQuery.textScalerOf(context).scale(label.fontSize!) /
        label.fontSize!;
    final width = BookletSize.shellRail * math.max(1, scale);
    return SizedBox(
      width: width,
      child: NavigationRail(
        selectedIndex: selectedIndex,
        onDestinationSelected: onDestinationSelected,
        minWidth: width,
        scrollable: true,
        groupAlignment: -1,
        backgroundColor: theme.colorScheme.surface,
        labelType: NavigationRailLabelType.all,
        useIndicator: true,
        indicatorColor: theme.colorScheme.primaryContainer,
        indicatorShape: _indicator,
        selectedIconTheme: IconThemeData(color: theme.colorScheme.primary),
        unselectedIconTheme: IconThemeData(
          color: theme.colorScheme.onSurfaceVariant,
        ),
        selectedLabelTextStyle: label.copyWith(fontWeight: FontWeight.w700),
        unselectedLabelTextStyle: label.copyWith(fontWeight: FontWeight.w500),
        leading: const Padding(
          padding: EdgeInsets.symmetric(vertical: BookletSpace.s4),
          child: ShellMonogram(),
        ),
        destinations: [
          for (final destination in AppShellDestination.values)
            NavigationRailDestination(
              icon: Icon(destination.icon),
              selectedIcon: Icon(destination.selectedIcon),
              label: SizedBox(
                width: width - BookletSpace.s4,
                child: Text(destination.label, textAlign: TextAlign.center),
              ),
            ),
        ],
      ),
    );
  }

  Widget _drawer(BuildContext context) {
    final theme = Theme.of(context);
    final label = theme.textTheme.labelLarge!;
    const labelWidth =
        BookletSize.shellSidebar -
        BookletSpace.s6 -
        BookletSpace.s4 -
        BookletSpace.s6 -
        BookletSpace.s3;
    final height = math.max(
      BookletSize.touchTarget,
      maxShellLabelHeight(
            context,
            label,
            labelWidth,
            MediaQuery.textScalerOf(context),
          ) +
          BookletSpace.s4,
    );
    return SizedBox(
      width: BookletSize.shellSidebar,
      child: NavigationDrawerTheme(
        data: NavigationDrawerThemeData(
          tileHeight: height,
          indicatorSize: Size(
            BookletSize.shellSidebar - BookletSpace.s6,
            height,
          ),
          labelTextStyle: WidgetStateProperty.resolveWith(
            (states) => label.copyWith(
              fontWeight: states.contains(WidgetState.selected)
                  ? FontWeight.w700
                  : FontWeight.w500,
            ),
          ),
        ),
        child: NavigationDrawer(
          selectedIndex: selectedIndex,
          onDestinationSelected: onDestinationSelected,
          backgroundColor: theme.colorScheme.surface,
          elevation: 0,
          indicatorColor: theme.colorScheme.primaryContainer,
          indicatorShape: _indicator,
          children: [
            const ShellWordmark(),
            const Divider(),
            const SizedBox(height: BookletSpace.s3),
            for (final destination in AppShellDestination.values)
              NavigationDrawerDestination(
                icon: Icon(
                  destination.icon,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                selectedIcon: Icon(
                  destination.selectedIcon,
                  color: theme.colorScheme.primary,
                ),
                label: SizedBox(
                  width: labelWidth,
                  child: Text(destination.label),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
