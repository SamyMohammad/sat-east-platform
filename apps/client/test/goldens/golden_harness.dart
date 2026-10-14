import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/theme/app_theme.dart';
import 'package:sat_east_client/core/theme/booklet_tokens.dart';

const List<double> goldenWidths = [360.0, 1280.0];

const ValueKey<String> _boundary = ValueKey('golden-boundary');

/// Pumps [child] in the booklet theme at [width] and compares it with
/// `goldens/<name>.png` next to the calling test. Wide layouts are capped at
/// the question column, as in QuestionView.
Future<void> expectGolden(
  WidgetTester tester, {
  required String name,
  required Widget child,
  required double width,
  Brightness brightness = Brightness.light,
  double textScale = 1,
  bool freezeAnimations = false,
}) async {
  tester.view.physicalSize = Size(width, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final theme = brightness == Brightness.light
      ? AppTheme.light()
      : AppTheme.dark();
  final animations = ValueNotifier<bool>(true);
  addTearDown(animations.dispose);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme,
      home: MediaQuery.withClampedTextScaling(
        minScaleFactor: textScale,
        maxScaleFactor: textScale,
        child: Scaffold(
          body: SingleChildScrollView(
            child: RepaintBoundary(
              key: _boundary,
              child: ColoredBox(
                color: theme.colorScheme.surface,
                child: Padding(
                  padding: const EdgeInsets.all(BookletSpace.s4),
                  child: Align(
                    alignment: AlignmentDirectional.topStart,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: BookletSize.questionColumn,
                      ),
                      child: freezeAnimations
                          ? ValueListenableBuilder<bool>(
                              valueListenable: animations,
                              builder: (context, enabled, child) => TickerMode(
                                enabled: enabled,
                                child: child!,
                              ),
                              child: child,
                            )
                          : child,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  if (freezeAnimations) {
    // Sample a visible loading phase before stopping decorative tickers.
    await tester.pump();
    await tester.pump(BookletMotion.base);
    animations.value = false;
  }
  await tester.pumpAndSettle();
  await expectLater(
    find.byKey(_boundary),
    matchesGoldenFile('goldens/$name.png'),
  );
}
