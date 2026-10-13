import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/theme/app_theme.dart';
import 'package:sat_east_client/core/theme/booklet_tokens.dart';
import 'package:sat_east_client/shared/widgets/focus_ring.dart';
import 'package:sat_east_client/shared/widgets/painters/dashed_border.dart';
import 'package:sat_east_client/shared/widgets/painters/strike_through.dart';

Widget _host(Widget child, {bool reduced = false}) => MaterialApp(
  theme: AppTheme.light(),
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduced),
    child: Center(child: SizedBox(width: 200, height: 56, child: child)),
  ),
);

double _progress(WidgetTester tester) {
  final paint = tester.widget<CustomPaint>(
    find.descendant(
      of: find.byType(StrikeThrough),
      matching: find.byType(CustomPaint),
    ),
  );
  return (paint.foregroundPainter! as StrikeThroughPainter).progress.value;
}

void main() {
  testWidgets('F-4: strike starts drawn when struck initially', (t) async {
    await t.pumpWidget(
      _host(
        const StrikeThrough(
          struck: true,
          color: Colors.black,
          child: SizedBox.expand(),
        ),
      ),
    );
    expect(_progress(t), 1);
  });

  testWidgets('F-4: strike animates in over motion.base', (t) async {
    Widget build({required bool struck}) => _host(
      StrikeThrough(
        struck: struck,
        color: Colors.black,
        child: const SizedBox.expand(),
      ),
    );
    await t.pumpWidget(build(struck: false));
    expect(_progress(t), 0);
    await t.pumpWidget(build(struck: true));
    await t.pump(BookletMotion.base ~/ 2);
    expect(_progress(t), inExclusiveRange(0, 1));
    await t.pump(BookletMotion.base);
    expect(_progress(t), 1);
  });

  testWidgets('F-4: reduced motion finishes the strike within motion.fast', (
    t,
  ) async {
    Widget build({required bool struck}) => _host(
      StrikeThrough(
        struck: struck,
        color: Colors.black,
        child: const SizedBox.expand(),
      ),
      reduced: true,
    );
    await t.pumpWidget(build(struck: false));
    await t.pumpWidget(build(struck: true));
    await t.pump(BookletMotion.fast);
    expect(_progress(t), 1);
  });

  test('F-4: dashed border repaints only when its look changes', () {
    const a = DashedBorderPainter(color: Colors.black, radius: 4);
    expect(
      a.shouldRepaint(
        const DashedBorderPainter(color: Colors.black, radius: 4),
      ),
      isFalse,
    );
    expect(
      a.shouldRepaint(const DashedBorderPainter(color: Colors.red, radius: 4)),
      isTrue,
    );
  });

  testWidgets('F-4: dashed border paints without error', (t) async {
    await t.pumpWidget(
      _host(
        const CustomPaint(
          foregroundPainter: DashedBorderPainter(
            color: Colors.black,
            radius: 4,
          ),
        ),
      ),
    );
    expect(t.takeException(), isNull);
  });

  test('F-4: focus ring sits 2 px outside the child', () {
    final rect = FocusRingPainter.ringRect(const Size(100, 50));
    const outset = BookletStroke.focusGap + BookletStroke.focusRing / 2;
    expect(
      rect,
      const Rect.fromLTRB(-outset, -outset, 100 + outset, 50 + outset),
    );
  });

  testWidgets('F-4: focus ring paints only when visible', (t) async {
    Future<CustomPainter?> painter({required bool visible}) async {
      await t.pumpWidget(
        _host(
          FocusRing(
            visible: visible,
            borderRadius: 4,
            child: const SizedBox.expand(),
          ),
        ),
      );
      return t
          .widget<CustomPaint>(
            find.descendant(
              of: find.byType(FocusRing),
              matching: find.byType(CustomPaint),
            ),
          )
          .foregroundPainter;
    }

    expect(await painter(visible: false), isNull);
    expect(await painter(visible: true), isA<FocusRingPainter>());
  });
}
