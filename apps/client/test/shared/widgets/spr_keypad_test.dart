import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:sat_east_client/core/grading/spr_editing.dart';
import 'package:sat_east_client/core/theme/app_theme.dart';
import 'package:sat_east_client/shared/widgets/spr_keypad.dart';

Future<(List<SprKey>, List<bool>)> pumpKeypad(
  WidgetTester tester, {
  double width = 360,
  double textScale = 1,
  TextDirection direction = TextDirection.ltr,
}) async {
  final keys = <SprKey>[];
  final hides = <bool>[];
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: MediaQuery.withClampedTextScaling(
        minScaleFactor: textScale,
        maxScaleFactor: textScale,
        child: Directionality(
          textDirection: direction,
          child: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: SprKeypad(onKey: keys.add, onHide: () => hides.add(true)),
            ),
          ),
        ),
      ),
    ),
  );
  return (keys, hides);
}

void main() {
  testWidgets('F-4: Tab focuses a key and Enter and Space activate it', (
    t,
  ) async {
    final (keys, hides) = await pumpKeypad(t);
    await t.sendKeyEvent(LogicalKeyboardKey.tab);
    await t.pump();
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    await t.pump();
    expect(keys, [SprKey.one]);
    await t.sendKeyEvent(LogicalKeyboardKey.space);
    await t.pump();
    expect(keys, [SprKey.one, SprKey.one]);
    expect(hides, isEmpty);
  });

  testWidgets('F-4: digit keys emit their key', (t) async {
    final (keys, _) = await pumpKeypad(t);
    for (var digit = 0; digit <= 9; digit++) {
      await t.tap(find.text('$digit'));
    }
    expect(keys, [
      for (var digit = 0; digit <= 9; digit++) SprKey.digit(digit),
    ]);
  });

  testWidgets('F-4: minus key shows U+2212 and emits SprKey.minus', (t) async {
    final (keys, _) = await pumpKeypad(t);
    await t.tap(find.text('−'));
    expect(keys, [SprKey.minus]);
  });

  testWidgets('F-4: slash, dot and delete emit their keys', (t) async {
    final (keys, _) = await pumpKeypad(t);
    await t.tap(find.text('/'));
    await t.tap(find.text('.'));
    await t.tap(find.bySemanticsLabel('Delete'));
    expect(keys, [SprKey.slash, SprKey.dot, SprKey.backspace]);
  });

  testWidgets('F-4: hide key calls onHide', (t) async {
    final (keys, hides) = await pumpKeypad(t);
    await t.tap(find.bySemanticsLabel('Hide keypad'));
    expect(hides, hasLength(1));
    expect(keys, isEmpty);
  });

  testWidgets('F-4: pressed key uses the primary container', (t) async {
    await pumpKeypad(t);
    final gesture = await t.startGesture(t.getCenter(find.text('8')));
    await t.pump();
    final box = t.widget<Container>(
      find.ancestor(of: find.text('8'), matching: find.byType(Container)).first,
    );
    expect(
      (box.decoration! as BoxDecoration).color,
      AppTheme.light().colorScheme.primaryContainer,
    );
    await gesture.up();
  });

  testWidgets('F-4: keys are 56 px tall', (t) async {
    await pumpKeypad(t);
    final box = find
        .ancestor(of: find.text('5'), matching: find.byType(Container))
        .first;
    expect(t.getSize(box).height, 56);
  });

  testWidgets('F-4: zero spans two digit columns and the gap', (t) async {
    await pumpKeypad(t);
    final zero = find
        .ancestor(of: find.text('0'), matching: find.byType(Container))
        .first;
    final digit = find
        .ancestor(of: find.text('5'), matching: find.byType(Container))
        .first;
    expect(t.getSize(zero).width, t.getSize(digit).width * 2 + 8);
  });

  testWidgets('F-4: keypad keeps LTR order under RTL', (t) async {
    await pumpKeypad(t, direction: TextDirection.rtl);
    expect(
      t.getCenter(find.text('1')).dx,
      lessThan(t.getCenter(find.text('3')).dx),
    );
  });

  testWidgets('F-4: 360 px at 2x text does not overflow', (t) async {
    await pumpKeypad(t, textScale: 2);
    expect(t.takeException(), isNull);
  });
}
