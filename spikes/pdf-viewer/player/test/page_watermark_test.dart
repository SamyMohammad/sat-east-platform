import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_spike/page_watermark.dart';

void main() {
  Widget page(double width, {VoidCallback? onTap}) => MaterialApp(
    home: Center(
      child: SizedBox(
        width: width,
        height: width * 1.41,
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: onTap,
                child: const ColoredBox(color: Colors.white),
              ),
            ),
            const PageWatermark(text: 'سارة أحمد · 53B17C'),
          ],
        ),
      ),
    ),
  );

  testWidgets('SEC-02 watermark repeats the identity across the page', (
    tester,
  ) async {
    await tester.pumpWidget(page(400));
    expect(find.text('سارة أحمد · 53B17C'), findsNWidgets(4));
  });

  testWidgets('SEC-02 watermark text scales with the page (zoom)', (
    tester,
  ) async {
    await tester.pumpWidget(page(300));
    final small = tester.widget<Text>(
      find.byKey(const Key('page-watermark-0')),
    );
    await tester.pumpWidget(page(600));
    final large = tester.widget<Text>(
      find.byKey(const Key('page-watermark-0')),
    );
    expect(large.style!.fontSize, closeTo(small.style!.fontSize! * 2, 0.01));
  });

  testWidgets('SEC-02 watermark never blocks taps on the page', (tester) async {
    var taps = 0;
    await tester.pumpWidget(page(400, onTap: () => taps++));
    await tester.tap(
      find.byKey(const Key('page-watermark-1')),
      warnIfMissed: false,
    );
    expect(taps, 1);
  });
}
