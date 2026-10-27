import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/math_render/math_text.dart';
import 'package:sat_east_client/core/theme/app_theme.dart';
import 'package:sat_east_client/core/theme/app_type.dart';

Future<void> pumpMath(
  WidgetTester tester,
  String source, {
  double width = 1280,
  double textScale = 1,
}) async {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: MediaQuery.withClampedTextScaling(
        minScaleFactor: textScale,
        maxScaleFactor: textScale,
        child: Scaffold(body: SingleChildScrollView(child: MathText(source))),
      ),
    ),
  );
}

void main() {
  testWidgets('F-4: English paragraphs remain separate and render LTR', (
    tester,
  ) async {
    await pumpMath(tester, 'Add 7 to both sides.\n\nDivide both sides by 3.');
    final paragraphs = tester
        .widgetList<Text>(find.byType(Text))
        .where((text) => text.textSpan != null)
        .toList();
    expect(paragraphs, hasLength(2));
    expect(paragraphs.first.textSpan!.toPlainText(), 'Add 7 to both sides.');
    expect(paragraphs.last.textSpan!.toPlainText(), 'Divide both sides by 3.');
    for (final paragraph in paragraphs) {
      expect(paragraph.textDirection, TextDirection.ltr);
    }
    expect(tester.takeException(), isNull);
  });

  group('F-4: inline math punctuation direction', () {
    final inlineMath = find.byWidgetPredicate(
      (w) => w.runtimeType.toString() == '_InlineMath',
    );

    TextDirection directionOf(WidgetTester t) =>
        Directionality.of(t.element(inlineMath));

    testWidgets('F-4: English only paragraph math sits under ltr', (
      tester,
    ) async {
      await pumpMath(tester, r'If \(x\), then');
      expect(inlineMath, findsOneWidget);
      expect(directionOf(tester), TextDirection.ltr);
    });
  });

  for (final (kind, source) in [
    ('inline', r'\(x=3\)'),
    ('block', r'\[x=3\]'),
  ]) {
    testWidgets('F-4: $kind math scales once at 2x text', (tester) async {
      await pumpMath(tester, source);
      final original = tester.getRect(find.byType(Math));

      await pumpMath(tester, source, textScale: 2);
      final enlarged = tester.getRect(find.byType(Math));

      expect(enlarged.width / original.width, closeTo(2, 0.05));
      expect(enlarged.height / original.height, closeTo(2, 0.05));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('F-4: glued inline punctuation scales once at 2x text', (
    tester,
  ) async {
    await pumpMath(tester, r'The answer is \(x=3\).');
    final original = tester.getRect(find.text('.'));

    await pumpMath(tester, r'The answer is \(x=3\).', textScale: 2);
    final enlarged = tester.getRect(find.text('.'));

    expect(enlarged.height / original.height, closeTo(2, 0.05));
    expect(enlarged.width / original.width, closeTo(2, 0.05));
    expect(tester.takeException(), isNull);
  });

  testWidgets('F-4: inline TeX renders through flutter_math', (tester) async {
    await pumpMath(tester, r'If \(2x+3=11\), find x.');
    expect(find.byType(Math), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('F-4: invalid TeX falls back to its source', (tester) async {
    await pumpMath(tester, r'Bad \(\frac{\) here');
    expect(find.text(r'\frac{'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('F-4: trailing punctuation sticks to the formula', (
    tester,
  ) async {
    await pumpMath(tester, r'The answer is \(x=4\).');
    expect(
      find.descendant(of: find.byType(Row), matching: find.text('.')),
      findsOneWidget,
    );
  });

  testWidgets('F-4: || block wraps chunks', (tester) async {
    await pumpMath(tester, r'\[a=1 || b=2 || c=3\]');
    expect(find.byType(Wrap), findsOneWidget);
    expect(find.byType(Math), findsNWidgets(3));
  });

  testWidgets('F-4: text around a block equation has no stray edge spaces', (
    tester,
  ) async {
    await pumpMath(tester, r'Solve \[x=1\] for x.');
    final texts = tester
        .widgetList<RichText>(find.byType(RichText))
        .map((r) => r.text.toPlainText())
        .toList();
    expect(texts, contains('Solve'));
    expect(texts, contains('for x.'));
  });

  testWidgets('F-4: 360 px at 2x text scale does not overflow', (tester) async {
    await pumpMath(
      tester,
      r'Solve \[\frac{3}{x-2}+\frac{5}{x+2}=\frac{4x+1}{x^2-4}+\frac{7}{x^2+4x+4}\] '
      'and explain each step in a sentence long enough to wrap twice.',
      width: 360,
      textScale: 2,
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(SingleChildScrollView), findsWidgets);
  });
  testWidgets('F-4: stem and choice math use the same glyph style', (
    tester,
  ) async {
    Future<TextStyle> mathGlyphStyle(TextStyle? style) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(body: MathText(r'\(x\)', style: style)),
        ),
      );
      final math = tester.widget<Math>(find.byType(Math));
      return math.textStyle!;
    }

    final stem = await mathGlyphStyle(AppType.stem);
    final choice = await mathGlyphStyle(null);

    // A heavier body weight must not change the math face (upright x).
    expect(stem.fontWeight, choice.fontWeight);
    expect(stem.fontWeight, FontWeight.w400);
    expect(stem.fontStyle, choice.fontStyle);
  });
}
