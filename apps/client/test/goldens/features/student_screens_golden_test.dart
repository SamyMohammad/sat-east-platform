@Tags(['golden'])
library;

import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';

import 'feature_golden_harness.dart';
import 'student_preview_fixtures.dart';

void main() {
  for (final screen in [
    'homework',
    'video_player',
    'notes_viewer',
    'attempt_review',
  ]) {
    for (final width in [360.0, 1280.0]) {
      for (final brightness in Brightness.values) {
        final name = '${screen}_${brightness.name}_${width.toInt()}';
        testWidgets('golden $name', (tester) async {
          await expectFeatureGolden(
            tester,
            name: name,
            width: width,
            brightness: brightness,
            location: '/preview',
            child: studentPreview(screen),
          );
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        });
      }
    }
  }
}
