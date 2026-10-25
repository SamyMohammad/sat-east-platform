import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/theme/app_theme.dart';
import 'package:sat_east_client/features/video/domain/services/video_engine.dart';
import 'package:sat_east_client/features/video/presentation/widgets/video_controls.dart';

void main() {
  for (final width in [360.0, 1280.0]) {
    testWidgets('LRN-02: controls fit $width with exact speeds and shortcuts', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      var toggles = 0;
      double? rate;
      double? seek;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: VideoControls(
              status: EngineStatus.paused,
              positionS: 12,
              durationS: 600,
              rate: 1,
              fullscreen: false,
              onTogglePlay: () => toggles++,
              onSeek: (s) => seek = s,
              onSetRate: (r) => rate = r,
              onToggleFullscreen: () {},
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('0:12 / 10:00'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      expect(toggles, 1);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      expect(seek, 22);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      expect(seek, 2);
      await tester.tap(find.text('1\u00d7'));
      await tester.pumpAndSettle();
      expect(find.text('1.25\u00d7'), findsOneWidget);
      expect(find.text('1.5\u00d7'), findsOneWidget);
      await tester.tap(find.text('1.5\u00d7'));
      await tester.pumpAndSettle();
      expect(rate, 1.5);
      expect(tester.takeException(), isNull);
    });
  }
}
