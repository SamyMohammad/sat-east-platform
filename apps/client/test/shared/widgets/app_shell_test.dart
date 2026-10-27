import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/theme/app_colors.dart';
import 'package:sat_east_client/core/theme/app_icons.dart';
import 'package:sat_east_client/core/theme/app_theme.dart';
import 'package:sat_east_client/core/theme/app_tokens.dart';
import 'package:sat_east_client/shared/widgets/app_shell/app_shell.dart';
import 'package:sat_east_client/shared/widgets/app_shell/app_shell_destination.dart';
import 'package:sat_east_client/shared/widgets/app_shell/focus_mode_scaffold.dart';
import 'package:sat_east_client/shared/widgets/app_shell/shell_branch_stack.dart';
import 'package:sat_east_client/shared/widgets/app_shell/shell_header.dart';

void main() {
  for (final reduced in [false, true]) {
    testWidgets(
      'branch fade preserves state and respects reduced motion: $reduced',
      (tester) async {
        var index = 0;
        late StateSetter update;
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(disableAnimations: reduced),
              child: StatefulBuilder(
                builder: (context, setState) {
                  update = setState;
                  return Scaffold(
                    body: ShellBranchStack(
                      currentIndex: index,
                      children: const [
                        _StatefulBody(),
                        Text('Second branch'),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        );
        await tester.tap(find.text('Increment'));
        update(() => index = 1);
        await tester.pump();
        final opacity = tester
            .widget<FadeTransition>(
              find
                  .ancestor(
                    of: find.text('Second branch'),
                    matching: find.byType(FadeTransition),
                  )
                  .first,
            )
            .opacity
            .value;
        expect(opacity, reduced ? 1 : 0);
        await tester.pumpAndSettle();
        update(() => index = 0);
        await tester.pumpAndSettle();
        expect(find.text('Count: 1'), findsOneWidget);
      },
    );
  }

  testWidgets('desktop sidebar uses surface and raised bordered selection', (
    tester,
  ) async {
    _viewport(tester, const Size(1280, 800));
    await _pumpShell(tester);
    final drawer = tester.widget<NavigationDrawer>(
      find.byType(NavigationDrawer),
    );
    final context = tester.element(find.byType(NavigationDrawer));
    expect(drawer.backgroundColor, context.appColors.surface);
    expect(drawer.indicatorColor, context.appColors.raised);
    final shape = drawer.indicatorShape! as RoundedRectangleBorder;
    expect(shape.side.color, context.appColors.line);
    expect(shape.side.width, 1);
  });

  testWidgets('desktop sidebar is a straight panel with one right border', (
    tester,
  ) async {
    _viewport(tester, const Size(1280, 800));
    await _pumpShell(tester);
    final context = tester.element(find.byType(NavigationDrawer));
    final material = tester.widget<Material>(
      find
          .descendant(
            of: find.byType(NavigationDrawer),
            matching: find.byType(Material),
          )
          .first,
    );
    final shape = material.shape;
    expect(shape, isA<Border>());
    final border = shape! as Border;
    expect(border.right.color, context.appColors.line);
    expect(border.right.width, 1);
    expect(border.left, BorderSide.none);
    // The shell adds no second divider next to the sidebar.
    expect(
      find.ancestor(
        of: find.byType(NavigationDrawer),
        matching: find.byWidgetPredicate(
          (w) =>
              w is DecoratedBox &&
              (w.decoration is BoxDecoration) &&
              (w.decoration as BoxDecoration).border != null,
        ),
      ),
      findsNothing,
    );
  });

  for (final width in [360.0, 600.0, 601.0, 768.0, 1023.0, 1024.0, 1280.0]) {
    testWidgets('F-4: shell uses native navigation at width $width', (
      tester,
    ) async {
      _viewport(tester, Size(width, 800));
      await _pumpShell(tester);

      _expectNavigation(width, selectedIndex: 0);
      expect(find.text('Page content'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final width in [360.0, 768.0, 1280.0]) {
    testWidgets(
      'F-4: default shell header uses its designed height '
      'at $width',
      (tester) async {
        _viewport(tester, Size(width, 800));
        await _pumpShell(tester);

        final expectedHeight = switch (width) {
          <= 600 => AppSize.shellCompactHeader,
          < 1024 => AppSize.shellMediumHeader,
          _ => AppSize.shellExpandedHeader,
        };
        expect(tester.getSize(find.byType(ShellHeader)).height, expectedHeight);
      },
    );

    testWidgets('F-4: every destination dispatches its index at $width', (
      tester,
    ) async {
      _viewport(tester, Size(width, 800));
      final selections = <int>[];
      await _pumpShell(tester, onSelected: selections.add);

      for (final destination in AppShellDestination.values) {
        final label = _navigationLabel(destination.label);
        await tester.ensureVisible(label);
        await tester.tap(label);
        await tester.pumpAndSettle();
      }

      expect(selections, [0, 1, 2, 3, 4]);
    });

    testWidgets('F-4: shell reflects selected profile at $width', (
      tester,
    ) async {
      _viewport(tester, Size(width, 800));
      final semantics = tester.ensureSemantics();
      try {
        await _pumpShell(tester, selectedIndex: 4);
        _expectNavigation(width, selectedIndex: 4);
        expect(
          find.descendant(
            of: _navigationFinder(),
            matching: find.byIcon(AppShellDestination.profile.selectedIcon),
          ),
          findsOneWidget,
        );
      } finally {
        semantics.dispose();
      }
    });

    testWidgets('F-4: keyboard skip reaches body input at $width', (
      tester,
    ) async {
      _viewport(tester, Size(width, 800));
      final inputFocus = FocusNode();
      final semantics = tester.ensureSemantics();
      try {
        await _pumpShell(
          tester,
          child: TextField(focusNode: inputFocus),
        );
        expect(find.bySemanticsLabel('Skip to content'), findsNothing);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        expect(find.text('Skip to content'), findsOneWidget);
        final skipLink = find.bySemanticsLabel('Skip to content');
        expect(skipLink, findsOneWidget);
        expect(
          tester.getSemantics(skipLink).flagsCollection.isFocused,
          Tristate.isTrue,
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        expect(inputFocus.hasFocus, isTrue);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        semantics.dispose();
        inputFocus.dispose();
      }
    });

    testWidgets(
      'F-4: doubled text and short shell can reach profile at $width',
      (
        tester,
      ) async {
        _viewport(tester, Size(width, 480));
        final selections = <int>[];
        await _pumpShell(tester, textScale: 2, onSelected: selections.add);

        final profile = _navigationLabel('Profile');
        if (width >= 1024) {
          await tester.scrollUntilVisible(
            profile,
            120,
            scrollable: find.descendant(
              of: find.byType(NavigationDrawer),
              matching: find.byType(Scrollable),
            ),
          );
          await tester.pumpAndSettle();
        }
        await tester.ensureVisible(profile);
        await tester.pumpAndSettle();
        await tester.tap(profile);
        await tester.pumpAndSettle();

        expect(selections, [4]);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('F-4: focus mode omits destination navigation at $width', (
      tester,
    ) async {
      _viewport(tester, Size(width, 800));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: FocusModeScaffold(
            appBar: AppBar(title: const Text('Practice')),
            bottomBar: const Text('Session actions'),
            child: const Text('Question content'),
          ),
        ),
      );

      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byType(NavigationRail), findsNothing);
      expect(find.byType(NavigationDrawer), findsNothing);
      expect(find.text('Practice'), findsOneWidget);
      expect(find.text('Session actions'), findsOneWidget);
      expect(find.text('Question content'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('F-4: resizing preserves body counter and edited text', (
    tester,
  ) async {
    _viewport(tester, const Size(360, 800));
    await _pumpShell(tester, selectedIndex: 2, child: const _StatefulBody());
    await tester.tap(find.text('Increment'));
    await tester.enterText(find.byType(TextField), 'Retained answer');

    for (final width in [768.0, 1280.0, 360.0]) {
      tester.view.physicalSize = Size(width, 800);
      await tester.pumpAndSettle();
      expect(find.text('Count: 1'), findsOneWidget);
      expect(find.text('Retained answer'), findsOneWidget);
      _expectNavigation(width, selectedIndex: 2);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('F-4: medium shell monogram retains its designed width', (
    tester,
  ) async {
    _viewport(tester, const Size(768, 800));
    await _pumpShell(tester);

    expect(
      tester.getSize(find.byType(ShellMonogram)).width,
      AppSize.shellMonogram,
    );
  });

  testWidgets('F-4: notifications dispatch only a supplied callback', (
    tester,
  ) async {
    var calls = 0;
    await _pumpShell(tester, onNotifications: () => calls++);
    await tester.tap(find.byTooltip('Notifications'));
    expect(calls, 1);
  });

  testWidgets('F-4: notifications are disabled without a callback', (
    tester,
  ) async {
    _viewport(tester, const Size(768, 800));
    final semantics = tester.ensureSemantics();
    try {
      await _pumpShell(tester);
      final button = find.widgetWithIcon(
        IconButton,
        AppIcons.notifications,
      );
      expect(tester.widget<IconButton>(button).onPressed, isNull);
      final notificationSemantics = tester.getSemantics(button);
      expect(
        notificationSemantics.flagsCollection.isEnabled,
        Tristate.isFalse,
      );
      await tester.tap(button);
      await tester.pumpAndSettle();
      _expectNavigation(768, selectedIndex: 0);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });
}

void _viewport(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

Future<void> _pumpShell(
  WidgetTester tester, {
  int selectedIndex = 0,
  ValueChanged<int>? onSelected,
  VoidCallback? onNotifications,
  double textScale = 1,
  Widget child = const Text('Page content'),
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
        ),
        child: child!,
      ),
      home: AppShell(
        selectedIndex: selectedIndex,
        onDestinationSelected: onSelected ?? (_) {},
        onNotifications: onNotifications,
        child: child,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _navigationFinder() => find.byWidgetPredicate(
  (widget) =>
      widget is NavigationBar ||
      widget is NavigationRail ||
      widget is NavigationDrawer,
);

Finder _navigationLabel(String label) => find.descendant(
  of: _navigationFinder(),
  matching: find.text(label),
);

void _expectNavigation(double width, {required int selectedIndex}) {
  expect(
    find.byType(NavigationBar),
    width <= 600 ? findsOneWidget : findsNothing,
  );
  expect(
    find.byType(NavigationRail),
    width > 600 && width < 1024 ? findsOneWidget : findsNothing,
  );
  expect(
    find.byType(NavigationDrawer),
    width >= 1024 ? findsOneWidget : findsNothing,
  );
  final navigation = _navigationFinder().evaluate().single.widget;
  final actual = switch (navigation) {
    NavigationBar(:final selectedIndex) => selectedIndex,
    NavigationRail(:final selectedIndex) => selectedIndex,
    NavigationDrawer(:final selectedIndex) => selectedIndex,
    _ => throw StateError('Expected native navigation'),
  };
  expect(actual, selectedIndex);
}

class _StatefulBody extends StatefulWidget {
  const _StatefulBody();

  @override
  State<_StatefulBody> createState() => _StatefulBodyState();
}

class _StatefulBodyState extends State<_StatefulBody> {
  final _controller = TextEditingController();
  var _count = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text('Count: $_count'),
      TextButton(
        onPressed: () => setState(() => _count++),
        child: const Text('Increment'),
      ),
      TextField(controller: _controller),
    ],
  );
}
