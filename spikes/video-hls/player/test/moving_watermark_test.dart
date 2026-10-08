import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hls_spike/moving_watermark.dart';

void main() {
  Future<Alignment> alignmentAfter(WidgetTester tester, Duration d) async {
    await tester.pump(d);
    await tester.pumpAndSettle();
    return tester.widget<AnimatedAlign>(find.byType(AnimatedAlign)).alignment
        as Alignment;
  }

  testWidgets('SEC-01 watermark shows the identity and moves on a timer', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MovingWatermark(text: 'Sara · A1B2C3', random: Random(1)),
      ),
    );
    expect(find.text('Sara · A1B2C3'), findsOneWidget);

    final start = await alignmentAfter(tester, Duration.zero);
    final before = await alignmentAfter(tester, const Duration(seconds: 4));
    expect(before, start, reason: 'does not move before the interval');

    final after = await alignmentAfter(tester, const Duration(seconds: 1));
    expect(after, isNot(start));
    expect(after.x.abs(), lessThanOrEqualTo(0.85));
    expect(after.y.abs(), lessThanOrEqualTo(0.85));
  });

  testWidgets('SEC-01 watermark never blocks taps on the player', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: () => taps++,
                child: const ColoredBox(color: Colors.black),
              ),
            ),
            const MovingWatermark(text: 'Sara · A1B2C3'),
          ],
        ),
      ),
    );
    await tester.tap(find.text('Sara · A1B2C3'), warnIfMissed: false);
    expect(taps, 1);
  });
}
