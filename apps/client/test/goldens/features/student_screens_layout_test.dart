import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:sat_east_client/core/theme/app_theme.dart';

import 'student_preview_fixtures.dart';

void main() {
  for (final screen in [
    'homework',
    'video_player',
    'notes_viewer',
    'attempt_review',
  ]) {
    for (final failed in [false, true]) {
      for (final dark in [false, true]) {
        testWidgets(
          '${screen}_no_overflow_at_360_text2x_dark_${dark}_error_$failed',
          (
            tester,
          ) async {
            tester.view.devicePixelRatio = 1;
            tester.view.physicalSize = const Size(360, 800);
            addTearDown(tester.view.reset);
            await tester.pumpWidget(
              MaterialApp(
                theme: dark ? AppTheme.dark() : AppTheme.light(),
                home: MediaQuery(
                  data: const MediaQueryData(
                    size: Size(360, 800),
                    textScaler: TextScaler.linear(2),
                    disableAnimations: true,
                  ),
                  child: studentPreview(screen, failed: failed),
                ),
              ),
            );
            await tester.pump();
            expect(tester.takeException(), isNull);
            if (failed) {
              await tester.scrollUntilVisible(find.text('Retry'), 100);
              expect(find.text('Retry'), findsOneWidget);
              expect(tester.takeException(), isNull);
            }
            await tester.pumpWidget(const SizedBox.shrink());
          },
        );
      }
    }
  }
}
