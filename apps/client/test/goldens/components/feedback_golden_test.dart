@Tags(['golden'])
library;

import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';

import '../feedback_samples.dart';
import '../golden_harness.dart';

void main() {
  final sheets = <String, Widget Function()>{
    'controls': controlsSheet,
    'statuses': statusesSheet,
    'overlays': overlaysSheet,
  };
  for (final entry in sheets.entries) {
    for (final brightness in Brightness.values) {
      for (final width in goldenWidths) {
        final name = '${entry.key}_${brightness.name}_${width.toInt()}';
        testWidgets('F-4: golden $name', (tester) async {
          await expectGolden(
            tester,
            name: name,
            width: width,
            brightness: brightness,
            freezeAnimations: true,
            child: entry.value(),
          );
        });
      }
    }
    final name = '${entry.key}_light_360_text2x';
    testWidgets('F-4: golden $name', (tester) async {
      await expectGolden(
        tester,
        name: name,
        width: 360,
        textScale: 2,
        freezeAnimations: true,
        child: entry.value(),
      );
    });
  }
}
