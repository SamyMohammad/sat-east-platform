import 'package:flutter/material.dart';
import 'package:sat_east_client/core/theme/app_tokens.dart';
import 'package:sat_east_client/shared/widgets/app_shell/app_shell_destination.dart';
import 'package:sat_east_client/shared/widgets/app_shell/shell_header.dart';
import 'package:sat_east_client/shared/widgets/app_shell/shell_navigation.dart';

class AppShell extends StatefulWidget {
  const AppShell({
    required this.child,
    required this.selectedIndex,
    required this.onDestinationSelected,
    super.key,
    this.onNotifications,
  }) : assert(
         selectedIndex >= 0 &&
             selectedIndex < AppShellDestination.destinationCount,
         'selectedIndex must identify a shell destination.',
       );

  final Widget child;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final VoidCallback? onNotifications;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final _skipFocus = FocusNode(debugLabel: 'Skip to content');
  final _contentFocus = FocusNode(
    debugLabel: 'Shell content',
    skipTraversal: true,
  );

  @override
  void initState() {
    super.initState();
    _skipFocus.addListener(_updateSkipVisibility);
  }

  void _updateSkipVisibility() => setState(() {});

  @override
  void dispose() {
    _skipFocus
      ..removeListener(_updateSkipVisibility)
      ..dispose();
    _contentFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.forWidth(MediaQuery.sizeOf(context).width);
    final compact = layout == AppLayout.compact;
    final margin = switch (layout) {
      AppLayout.compact => AppSpace.s4,
      AppLayout.medium => AppSpace.s6,
      AppLayout.expanded => AppSpace.s8,
    };
    return Scaffold(
      body: SafeArea(
        bottom: !compact,
        child: FocusTraversalGroup(
          policy: OrderedTraversalPolicy(),
          child: Stack(
            children: [
              Column(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        if (!compact)
                          _ordered(
                            1,
                            DecoratedBox(
                              decoration: BoxDecoration(
                                border: BorderDirectional(
                                  end: BorderSide(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.outlineVariant,
                                  ),
                                ),
                              ),
                              child: _navigation(layout),
                            ),
                          ),
                        Expanded(
                          key: const ValueKey('shell-content'),
                          child: Column(
                            children: [
                              _ordered(
                                2,
                                ShellHeader(
                                  layout: layout,
                                  destination: AppShellDestination
                                      .values[widget.selectedIndex],
                                  onNotifications: widget.onNotifications,
                                ),
                              ),
                              Expanded(
                                child: _ordered(
                                  3,
                                  Focus(
                                    focusNode: _contentFocus,
                                    child: Padding(
                                      padding: EdgeInsets.all(margin),
                                      child: widget.child,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (compact) _ordered(1, _navigation(layout)),
                ],
              ),
              PositionedDirectional(
                top: AppSpace.s2,
                start: AppSpace.s2,
                child: _skipLink(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _ordered(double order, Widget child) => FocusTraversalOrder(
    order: NumericFocusOrder(order),
    child: FocusTraversalGroup(child: child),
  );

  Widget _navigation(AppLayout layout) => ShellNavigation(
    layout: layout,
    selectedIndex: widget.selectedIndex,
    onDestinationSelected: widget.onDestinationSelected,
  );

  Widget _skipLink(BuildContext context) => _ordered(
    0,
    ExcludeSemantics(
      excluding: !_skipFocus.hasFocus,
      child: IgnorePointer(
        ignoring: !_skipFocus.hasFocus,
        child: Opacity(
          opacity: _skipFocus.hasFocus ? 1 : 0,
          child: Material(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(AppRadius.control),
            child: TextButton(
              focusNode: _skipFocus,
              onPressed: _contentFocus.requestFocus,
              child: const Text('Skip to content'),
            ),
          ),
        ),
      ),
    ),
  );
}
