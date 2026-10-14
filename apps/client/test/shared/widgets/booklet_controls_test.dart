import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:sat_east_client/core/theme/app_theme.dart';
import 'package:sat_east_client/shared/widgets/booklet_banner.dart';
import 'package:sat_east_client/shared/widgets/booklet_chip.dart';
import 'package:sat_east_client/shared/widgets/loading_button.dart';

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  bool dark = false,
  bool reducedMotion = false,
  double scale = 1,
  double width = 360,
}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: dark ? AppTheme.dark() : AppTheme.light(),
      home: Scaffold(
        body: MediaQuery(
          data: MediaQueryData(
            size: Size(width, 900),
            textScaler: TextScaler.linear(scale),
            disableAnimations: reducedMotion,
          ),
          child: SingleChildScrollView(
            child: Padding(padding: const EdgeInsets.all(16), child: child),
          ),
        ),
      ),
    ),
  );
}

Future<void> _keyboardActivate(WidgetTester tester) async {
  await tester.sendKeyEvent(LogicalKeyboardKey.tab);
  await tester.sendKeyEvent(LogicalKeyboardKey.enter);
  await tester.sendKeyEvent(LogicalKeyboardKey.space);
  await tester.pump();
}

void main() {
  testWidgets('F-4: wide banner places its action at the trailing edge', (
    tester,
  ) async {
    await _pump(
      tester,
      BookletBanner(
        message: 'Desmos is available on every question in this module.',
        actionLabel: 'Got it',
        onAction: () {},
      ),
      width: 1280,
    );
    final banner = tester.getRect(find.byType(BookletBanner));
    final action = tester.getRect(find.text('Got it'));
    expect(action.center.dx, greaterThan(banner.left + banner.width * .75));
  });
  for (final kind in [BookletChipKind.skill, BookletChipKind.filter]) {
    testWidgets('F-4: $kind chip preserves multiline label with icon at 2x', (
      tester,
    ) async {
      const label =
          'Review all the marked questions before continuing '
          'to the next topic';
      await _pump(
        tester,
        BookletChip(
          label: label,
          kind: kind,
          selected: true,
          icon: Icons.sell_outlined,
          onSelected: (_) {},
        ),
        scale: 2,
      );
      final paragraph = tester.renderObject<RenderParagraph>(find.text(label));
      expect(paragraph.maxLines, isNull);
      expect(paragraph.softWrap, isTrue);
      final singleLine = TextPainter(
        text: paragraph.text,
        textDirection: TextDirection.ltr,
        textScaler: paragraph.textScaler,
      )..layout();
      try {
        expect(paragraph.size.height, greaterThan(singleLine.height));
      } finally {
        singleLine.dispose();
      }
      expect(tester.takeException(), isNull);
    });
  }
  for (final variant in BookletButtonVariant.values) {
    testWidgets('F-4: $variant button requests caller action', (tester) async {
      var calls = 0;
      await _pump(
        tester,
        LoadingButton(
          label: 'Continue',
          variant: variant,
          onPressed: () => calls++,
        ),
      );
      await tester.tap(find.text('Continue'));
      expect(calls, 1);
      expect(
        tester.getSize(find.byType(LoadingButton)).height,
        greaterThanOrEqualTo(48),
      );
    });
    testWidgets('F-4: $variant loading suppresses tap and keyboard', (
      tester,
    ) async {
      var calls = 0;
      final semantics = tester.ensureSemantics();
      try {
        await _pump(
          tester,
          LoadingButton(
            label: 'Checking',
            variant: variant,
            isLoading: true,
            onPressed: () => calls++,
          ),
          dark: true,
        );
        await tester.tap(find.text('Checking'));
        await _keyboardActivate(tester);
        expect(calls, 0);
        expect(find.bySemanticsLabel(RegExp('Checking')), findsWidgets);
      } finally {
        semantics.dispose();
      }
    });
    testWidgets('F-4: $variant disabled button ignores keyboard', (
      tester,
    ) async {
      await _pump(tester, LoadingButton(label: 'Continue', variant: variant));
      await tester.tap(find.text('Continue'));
      await _keyboardActivate(tester);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('F-4: enabled button supports keyboard activation', (
    tester,
  ) async {
    var calls = 0;
    await _pump(
      tester,
      LoadingButton(label: 'Continue', onPressed: () => calls++),
    );
    await _keyboardActivate(tester);
    expect(calls, greaterThan(0));
  });
  testWidgets('F-4: button displays caller error', (tester) async {
    await _pump(
      tester,
      LoadingButton(
        label: 'Retry',
        errorText: 'Not sent. Retry.',
        onPressed: () {},
      ),
    );
    expect(find.text('Not sent. Retry.'), findsOneWidget);
  });
  testWidgets('F-4: reduced motion loading has no scheduled animation', (
    tester,
  ) async {
    await _pump(
      tester,
      LoadingButton(label: 'Checking', isLoading: true, onPressed: () {}),
      reducedMotion: true,
    );
    await tester.pump(const Duration(seconds: 1));
    expect(tester.binding.hasScheduledFrame, isFalse);
  });
  testWidgets('F-4: filter selection stays controlled until caller rebuild', (
    tester,
  ) async {
    final changes = <bool>[];
    await _pump(
      tester,
      BookletChip(
        label: 'Algebra',
        kind: BookletChipKind.filter,
        onSelected: changes.add,
      ),
    );
    await tester.tap(find.text('Algebra'));
    await tester.pump();
    await tester.tap(find.text('Algebra'));
    expect(changes, [true, true]);
    await _pump(
      tester,
      BookletChip(
        label: 'Algebra',
        kind: BookletChipKind.filter,
        selected: true,
        onSelected: changes.add,
      ),
      dark: true,
    );
    await tester.tap(find.text('Algebra'));
    expect(changes.last, isFalse);
  });
  testWidgets('F-4: disabled filter has no tap semantics', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await _pump(
        tester,
        const BookletChip(label: 'Disabled', kind: BookletChipKind.filter),
      );
      expect(
        tester
            .getSemantics(find.bySemanticsLabel('Disabled'))
            .getSemanticsData()
            .hasAction(SemanticsAction.tap),
        isFalse,
      );
    } finally {
      semantics.dispose();
    }
  });
  for (final kind in [BookletChipKind.skill, BookletChipKind.difficulty]) {
    testWidgets('F-4: $kind tag is noninteractive', (tester) async {
      var calls = 0;
      final semantics = tester.ensureSemantics();
      try {
        await _pump(
          tester,
          BookletChip(
            label: 'Linear equations',
            kind: kind,
            onSelected: (_) => calls++,
          ),
        );
        await tester.tap(find.text('Linear equations'));
        expect(calls, 0);
        expect(
          tester
              .getSemantics(find.bySemanticsLabel('Linear equations'))
              .getSemanticsData()
              .hasAction(SemanticsAction.tap),
          isFalse,
        );
      } finally {
        semantics.dispose();
      }
    });
  }
  for (final kind in BookletBannerKind.values) {
    testWidgets('F-4: $kind banner announces live message and runs action', (
      tester,
    ) async {
      var calls = 0;
      final semantics = tester.ensureSemantics();
      try {
        await _pump(
          tester,
          BookletBanner(
            message: 'Your progress is saved.',
            kind: kind,
            actionLabel: 'Retry',
            onAction: () => calls++,
          ),
        );
        final node = tester.getSemantics(
          find.bySemanticsLabel(RegExp('Your progress is saved')),
        );
        expect(
          node.getSemanticsData().flagsCollection.isLiveRegion,
          isTrue,
        );
        await tester.tap(find.text('Retry'));
        expect(calls, 1);
      } finally {
        semantics.dispose();
      }
    });
  }
  test('F-4: banner requires action label and callback together', () {
    expect(
      () => BookletBanner(message: 'Saved', actionLabel: 'Retry'),
      throwsAssertionError,
    );
    expect(
      () => BookletBanner(message: 'Saved', onAction: () {}),
      throwsAssertionError,
    );
  });
  testWidgets('F-4: long controls wrap at 360 with doubled text', (
    tester,
  ) async {
    const copy =
        'Review all the marked questions before continuing to the next topic';
    await _pump(
      tester,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LoadingButton(label: copy, onPressed: () {}),
          const BookletChip(label: copy),
          BookletChip(
            label: copy,
            kind: BookletChipKind.filter,
            onSelected: (_) {},
          ),
          BookletBanner(message: copy, actionLabel: copy, onAction: () {}),
        ],
      ),
      scale: 2,
    );
    expect(tester.takeException(), isNull);
  });
}
