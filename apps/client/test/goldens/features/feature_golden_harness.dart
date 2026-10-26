import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../full_viewport_harness.dart';

Future<void> expectFeatureGolden(
  WidgetTester tester, {
  required String name,
  required double width,
  required Brightness brightness,
  required String location,
  required Widget child,
  double height = 800,
}) async {
  final router = GoRouter(
    initialLocation: location,
    routes: [GoRoute(path: location, builder: (_, _) => child)],
  );
  addTearDown(router.dispose);
  await expectViewportGolden(
    tester,
    name: name,
    width: width,
    height: height,
    brightness: brightness,
    directory: '../baselines',
    child: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: Router.withConfig(config: router),
      ),
    ),
  );
}
