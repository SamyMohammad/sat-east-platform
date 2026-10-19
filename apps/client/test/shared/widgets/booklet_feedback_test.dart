import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:sat_east_client/core/theme/app_theme.dart';
import 'package:sat_east_client/shared/widgets/booklet_dialog.dart';
import 'package:sat_east_client/shared/widgets/booklet_overlays.dart';
import 'package:sat_east_client/shared/widgets/booklet_progress.dart';
import 'package:sat_east_client/shared/widgets/booklet_skeleton.dart';
import 'package:sat_east_client/shared/widgets/empty_state.dart';
import 'package:sat_east_client/shared/widgets/error_retry.dart';

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  bool dark = false,
  bool reducedMotion = false,
  double scale = 1,
}) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: dark ? AppTheme.dark() : AppTheme.light(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(scale),
          disableAnimations: reducedMotion,
        ),
        child: child!,
      ),
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  testWidgets('PAY-01: empty state keeps both actions independent', (
    tester,
  ) async {
    var primary = 0;
    var secondary = 0;
    await _pump(
      tester,
      EmptyState(
        title: 'No course yet',
        message: 'Choose a course.',
        actionLabel: 'Enter activation code',
        onAction: () => primary++,
        secondaryActionLabel: 'Browse courses',
        onSecondaryAction: () => secondary++,
      ),
    );
    expect(
      tester.getTopLeft(find.text('Browse courses')).dy,
      greaterThan(tester.getBottomLeft(find.text('Enter activation code')).dy),
    );
    await tester.tap(find.text('Browse courses'));
    expect(secondary, 1);
    expect(primary, 0);
    await tester.tap(find.text('Enter activation code'));
    expect(primary, 1);
  });
  test('PAY-01: secondary empty action requires label and callback', () {
    expect(
      () => EmptyState(
        title: 'Empty',
        message: 'None',
        secondaryActionLabel: 'Browse',
      ),
      throwsAssertionError,
    );
    expect(
      () =>
          EmptyState(title: 'Empty', message: 'None', onSecondaryAction: () {}),
      throwsAssertionError,
    );
  });
  for (final sheet in [false, true]) {
    testWidgets(
      'F-4: ${sheet ? 'sheet' : 'dialog'} returns builder dismissal result',
      (tester) async {
        Future<String?>? result;
        await _pump(
          tester,
          Builder(
            builder: (context) => TextButton(
              onPressed: () {
                Widget content(BuildContext modalContext) => TextButton(
                  onPressed: () => Navigator.pop(modalContext, 'done'),
                  child: const Text('Done'),
                );
                result = sheet
                    ? showBookletSheet<String>(
                        context: context,
                        builder: content,
                      )
                    : showBookletDialog<String>(
                        context: context,
                        builder: (ctx) => BookletDialog(
                          title: 'Confirm',
                          content: content(ctx),
                        ),
                      );
              },
              child: const Text('Open'),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Done'));
        await tester.pumpAndSettle();
        expect(await result, 'done');
        expect(find.text('Done'), findsNothing);
      },
    );
    testWidgets(
      'F-4: ${sheet ? 'sheet' : 'dialog'} barrier dismisses with null',
      (tester) async {
        Future<String?>? result;
        await _pump(
          tester,
          Builder(
            builder: (context) => TextButton(
              onPressed: () {
                result = sheet
                    ? showBookletSheet<String>(
                        context: context,
                        builder: (_) => const Text('Reference'),
                      )
                    : showBookletDialog<String>(
                        context: context,
                        builder: (_) => const BookletDialog(
                          title: 'Confirm',
                          content: Text('Reference'),
                        ),
                      );
              },
              child: const Text('Open'),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        await tester.tapAt(const Offset(8, 8));
        await tester.pumpAndSettle();
        expect(await result, isNull);
      },
    );
    testWidgets(
      'F-4: ${sheet ? 'sheet' : 'dialog'} scrolls long content '
      'above keyboard at 2x',
      (tester) async {
        tester.view.viewInsets = const FakeViewPadding(bottom: 260);
        await _pump(
          tester,
          Builder(
            builder: (context) => TextButton(
              onPressed: () {
                Widget content(BuildContext ctx) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < 20; i++)
                      Text('Reference row $i with long explanatory copy'),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Finish'),
                    ),
                  ],
                );
                if (sheet) {
                  unawaited(
                    showBookletSheet<void>(
                      context: context,
                      builder: content,
                    ),
                  );
                } else {
                  unawaited(
                    showBookletDialog<void>(
                      context: context,
                      builder: (ctx) => BookletDialog(
                        title: 'Reference',
                        content: content(ctx),
                      ),
                    ),
                  );
                }
              },
              child: const Text('Open'),
            ),
          ),
          scale: 2,
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.text('Finish'));
        await tester.pumpAndSettle();
        expect(
          tester.getRect(find.text('Finish')).bottom,
          lessThanOrEqualTo(540),
        );
        await tester.tap(find.text('Finish'));
        await tester.pumpAndSettle();
        expect(find.text('Finish'), findsNothing);
      },
    );
  }
  testWidgets('F-4: nondismissible dialog ignores barrier tap', (tester) async {
    await _pump(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => showBookletDialog<void>(
            context: context,
            barrierDismissible: false,
            builder: (_) => const BookletDialog(
              title: 'Confirm',
              content: Text('Keep going'),
            ),
          ),
          child: const Text('Open'),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();
    expect(find.text('Confirm'), findsOneWidget);
  });
  testWidgets('F-4: snackbar action requests callback and closes', (
    tester,
  ) async {
    var calls = 0;
    ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? snack;
    await _pump(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () {
            snack = showBookletSnackBar(
              context: context,
              message: 'Choice D crossed out.',
              actionLabel: 'Undo',
              onAction: () => calls++,
            );
          },
          child: const Text('Open'),
        ),
      ),
      dark: true,
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(await snack!.closed, SnackBarClosedReason.action);
  });
  testWidgets(
    'F-4: reduced motion snackbar is visible and action remains usable',
    (
      tester,
    ) async {
      var calls = 0;
      await _pump(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showBookletSnackBar(
              context: context,
              message: 'Choice D crossed out.',
              actionLabel: 'Undo',
              onAction: () => calls++,
            ),
            child: const Text('Open'),
          ),
        ),
        reducedMotion: true,
      );
      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Choice D crossed out.').hitTestable(), findsOneWidget);
      expect(tester.binding.hasScheduledFrame, isFalse);
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(find.text('Choice D crossed out.'), findsNothing);
    },
  );
  for (final value in <double?>[
    null,
    double.nan,
    double.infinity,
    double.negativeInfinity,
  ]) {
    testWidgets('F-4: progress $value renders without fabricated completion', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      try {
        await _pump(
          tester,
          BookletProgress(label: 'Saving answers', value: value),
        );
        expect(
          tester
              .widget<LinearProgressIndicator>(
                find.byType(LinearProgressIndicator),
              )
              .value,
          isNull,
        );
        final node = tester.getSemantics(
          find.bySemanticsLabel('Saving answers'),
        );
        expect(node.getSemanticsData().value, isEmpty);
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    });
  }
  for (final (input, expected) in [(-0.5, 0.0), (0.4, 0.4), (2.0, 1.0)]) {
    testWidgets('F-4: progress clamps $input for rendering', (tester) async {
      await _pump(
        tester,
        BookletProgress(label: 'Topic progress', value: input),
      );
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        expected,
      );
    });
  }
  testWidgets('F-4: progress exposes caller value label', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await _pump(
        tester,
        const BookletProgress(
          label: 'Topic 4 of 40',
          value: .1,
          valueLabel: '10%',
        ),
      );
      expect(find.text('10%'), findsOneWidget);
      expect(
        tester
            .getSemantics(find.bySemanticsLabel('Topic 4 of 40'))
            .getSemanticsData()
            .value,
        '10%',
      );
    } finally {
      semantics.dispose();
    }
  });
  testWidgets('F-4: reduced motion indeterminate progress stops animation', (
    tester,
  ) async {
    await _pump(
      tester,
      const BookletProgress(label: 'Saving answers'),
      reducedMotion: true,
    );
    await tester.pump(const Duration(seconds: 1));
    expect(tester.binding.hasScheduledFrame, isFalse);
  });
  testWidgets('F-4: skeleton has a single static loading announcement', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await _pump(
        tester,
        const BookletSkeleton(label: 'Loading question'),
        dark: true,
      );
      expect(find.bySemanticsLabel('Loading question'), findsOneWidget);
      final node = tester.getSemantics(
        find.bySemanticsLabel('Loading question'),
      );
      final descendants = <SemanticsNode>[];
      node.visitChildren((child) {
        descendants.add(child);
        return true;
      });
      expect(descendants, isEmpty);
      await tester.pump(const Duration(seconds: 1));
      expect(tester.binding.hasScheduledFrame, isFalse);
    } finally {
      semantics.dispose();
    }
  });
  testWidgets('F-4: empty state optional action requests caller', (
    tester,
  ) async {
    var calls = 0;
    await _pump(
      tester,
      EmptyState(
        title: 'No mock exams yet',
        message: 'Keep going on your path.',
        actionLabel: 'Continue path',
        onAction: () => calls++,
      ),
    );
    await tester.tap(find.text('Continue path'));
    expect(calls, 1);
    await _pump(
      tester,
      const EmptyState(
        title: 'No mock exams yet',
        message: 'Keep going on your path.',
      ),
    );
    expect(find.text('Continue path'), findsNothing);
  });
  test('F-4: empty state action requires paired label and callback', () {
    expect(
      () => EmptyState(
        title: 'Empty',
        message: 'Nothing yet',
        actionLabel: 'Continue',
      ),
      throwsAssertionError,
    );
    expect(
      () => EmptyState(title: 'Empty', message: 'Nothing yet', onAction: () {}),
      throwsAssertionError,
    );
  });
  testWidgets('F-4: retry and secondary actions request caller', (
    tester,
  ) async {
    var retries = 0;
    var home = 0;
    await _pump(
      tester,
      ErrorRetry(
        title: 'Topic unavailable',
        message: 'Try again.',
        onRetry: () => retries++,
        secondaryLabel: 'Go home',
        onSecondary: () => home++,
      ),
    );
    await tester.tap(find.text('Retry'));
    await tester.tap(find.text('Go home'));
    expect(retries, 1);
    expect(home, 1);
  });
  testWidgets('F-4: retrying suppresses duplicate tap and keyboard', (
    tester,
  ) async {
    var retries = 0;
    await _pump(
      tester,
      ErrorRetry(
        title: 'Topic unavailable',
        message: 'Try again.',
        isRetrying: true,
        onRetry: () => retries++,
      ),
    );
    await tester.tap(find.text('Retry'));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(retries, 0);
  });
  test('F-4: retry secondary action requires paired label and callback', () {
    expect(
      () => ErrorRetry(
        title: 'Error',
        message: 'Try again',
        onRetry: () {},
        secondaryLabel: 'Go home',
      ),
      throwsAssertionError,
    );
    expect(
      () => ErrorRetry(
        title: 'Error',
        message: 'Try again',
        onRetry: () {},
        onSecondary: () {},
      ),
      throwsAssertionError,
    );
  });
  testWidgets('F-4: long status text wraps at 360 and 2x', (tester) async {
    const copy =
        'Your progress is saved. Check your connection and continue '
        'when you are ready.';
    await _pump(
      tester,
      SingleChildScrollView(
        child: Column(
          children: [
            EmptyState(
              title: copy,
              message: copy,
              actionLabel: copy,
              onAction: () {},
            ),
            ErrorRetry(
              title: copy,
              message: copy,
              onRetry: () {},
              secondaryLabel: copy,
              onSecondary: () {},
            ),
            const BookletProgress(label: copy, value: .5, valueLabel: copy),
          ],
        ),
      ),
      scale: 2,
    );
    expect(tester.takeException(), isNull);
  });
}
