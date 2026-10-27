import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:sat_east_client/core/theme/app_colors.dart';
import 'package:sat_east_client/core/theme/app_tokens.dart';
import 'package:sat_east_client/shared/widgets/app_shell/app_shell_destination.dart';
import 'package:sat_east_client/shared/widgets/app_shell/shell_bottom_navigation.dart';
import 'package:sat_east_client/shared/widgets/app_shell/shell_header.dart';
import 'package:sat_east_client/shared/widgets/app_shell/shell_navigation_metrics.dart';

class ShellNavigation extends StatelessWidget {
  const ShellNavigation({
    required this.layout,
    required this.selectedIndex,
    required this.onDestinationSelected,
    super.key,
  });

  final AppLayout layout;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  static const _indicator = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(AppRadius.control)),
  );

  @override
  Widget build(BuildContext context) => switch (layout) {
    AppLayout.compact => ShellBottomNavigation(
      selectedIndex: selectedIndex,
      onDestinationSelected: onDestinationSelected,
    ),
    AppLayout.medium => _rail(context),
    AppLayout.expanded => _drawer(context),
  };

  Widget _rail(BuildContext context) {
    final theme = Theme.of(context);
    final label = theme.textTheme.labelSmall!;
    final scale =
        MediaQuery.textScalerOf(context).scale(label.fontSize!) /
        label.fontSize!;
    final width = AppSize.shellRail * math.max(1, scale);
    return SizedBox(
      width: width,
      child: NavigationRail(
        selectedIndex: selectedIndex,
        onDestinationSelected: onDestinationSelected,
        minWidth: width,
        scrollable: true,
        groupAlignment: -1,
        backgroundColor: context.appColors.surface,
        labelType: NavigationRailLabelType.all,
        useIndicator: true,
        indicatorColor: context.appColors.raised,
        indicatorShape: _indicator.copyWith(
          side: BorderSide(color: context.appColors.line),
        ),
        selectedIconTheme: IconThemeData(color: theme.colorScheme.primary),
        unselectedIconTheme: IconThemeData(
          color: theme.colorScheme.onSurfaceVariant,
        ),
        selectedLabelTextStyle: label.copyWith(fontWeight: FontWeight.w700),
        unselectedLabelTextStyle: label.copyWith(fontWeight: FontWeight.w500),
        leading: const Padding(
          padding: EdgeInsets.symmetric(vertical: AppSpace.s4),
          child: ShellMonogram(),
        ),
        destinations: [
          for (final destination in AppShellDestination.values)
            NavigationRailDestination(
              icon: Icon(destination.icon),
              selectedIcon: Icon(destination.selectedIcon),
              label: SizedBox(
                width: width - AppSpace.s4,
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
        AppSize.shellSidebar -
        AppSpace.s6 -
        AppSpace.s4 -
        AppSpace.s6 -
        AppSpace.s3;
    final height = math.max(
      AppSize.touchTarget,
      maxShellLabelHeight(
            context,
            label,
            labelWidth,
            MediaQuery.textScalerOf(context),
          ) +
          AppSpace.s4,
    );
    return SizedBox(
      width: AppSize.shellSidebar,
      // Permanent sidebar: a straight panel with a hairline right edge, not
      // the M3 modal drawer's rounded end corners.
      child: DrawerTheme(
        data: DrawerThemeData(
          shape: Border(right: BorderSide(color: context.appColors.line)),
        ),
        child: NavigationDrawerTheme(
          data: NavigationDrawerThemeData(
            tileHeight: height,
            indicatorSize: Size(
              AppSize.shellSidebar - AppSpace.s6,
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
            backgroundColor: context.appColors.surface,
            elevation: 0,
            indicatorColor: context.appColors.raised,
            indicatorShape: _indicator.copyWith(
              side: BorderSide(color: context.appColors.line),
            ),
            children: [
              const ShellWordmark(),
              const Divider(),
              const SizedBox(height: AppSpace.s3),
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
      ),
    );
  }
}
