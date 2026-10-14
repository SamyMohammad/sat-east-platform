import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/theme/app_theme.dart';

const ValueKey<String> _viewportBoundary = ValueKey('full-viewport-golden');

/// Pumps [child] as the home of a themed [MaterialApp] at exactly
/// [width] x [height] (device pixel ratio 1) and compares the whole viewport
/// with `<directory>/<name>.png`, relative to the calling test file.
Future<void> expectViewportGolden(
  WidgetTester tester, {
  required String name,
  required double width,
  required double height,
  required Widget child,
  Brightness brightness = Brightness.light,
  double textScale = 1,
  String directory = 'goldens',
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, height);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    MaterialApp(
      theme: brightness == Brightness.light
          ? AppTheme.light()
          : AppTheme.dark(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: RepaintBoundary(key: _viewportBoundary, child: child),
    ),
  );
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
  await expectLater(
    find.byKey(_viewportBoundary),
    matchesGoldenFile('$directory/$name.png'),
  );
}
