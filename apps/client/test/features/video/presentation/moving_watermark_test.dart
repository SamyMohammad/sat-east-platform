import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/theme/app_theme.dart';
import 'package:sat_east_client/features/video/presentation/widgets/moving_watermark.dart';

void main() {
  testWidgets('SEC-01: watermark renders and moves after configured period', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: SizedBox(
          width: 360,
          height: 200,
          child: MovingWatermark(
            text: 'Sara Ali \u00b7 3FA2C1',
            period: const Duration(seconds: 7),
            random: Random(1),
          ),
        ),
      ),
    );
    expect(find.text('Sara Ali \u00b7 3FA2C1'), findsOneWidget);
    final before = tester.widget<AnimatedPositioned>(
      find.byType(AnimatedPositioned),
    );
    await tester.pump(const Duration(seconds: 7));
    final after = tester.widget<AnimatedPositioned>(
      find.byType(AnimatedPositioned),
    );
    expect((after.left, after.top), isNot((before.left, before.top)));
    expect(
      tester.widget<IgnorePointer>(find.byType(IgnorePointer).last).ignoring,
      isTrue,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
