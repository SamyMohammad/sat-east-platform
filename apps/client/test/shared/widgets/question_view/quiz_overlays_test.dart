import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/theme/app_theme.dart';
import 'package:sat_east_client/core/theme/booklet_tokens.dart';
import 'package:sat_east_client/shared/widgets/booklet_dialog.dart';
import 'package:sat_east_client/shared/widgets/question_view/parts/question_navigator.dart';
import 'package:sat_east_client/shared/widgets/question_view/parts/submit_dialog.dart';
import 'package:sat_east_client/shared/widgets/question_view/quiz_time_up_dialog.dart';

const _phone = Size(360, 800);
const _wide = Size(1280, 800);

const _total = 20;
const _title = 'Quiz 4.2 questions';
const _answered = {0, 1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 14, 15, 16};
const _unansweredChips = ['Q9', 'Q14', 'Q18', 'Q19', 'Q20'];
const _legend = ['Current', 'Answered', 'Unanswered', 'Marked for review'];

class _Calls {
  final jumps = <int>[];
  int submitPresses = 0;
  int submits = 0;
  int continues = 0;
}

final GlobalKey _hostKey = GlobalKey();

void _setSize(WidgetTester t, Size size) {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
}

BuildContext get _ctx => _hostKey.currentContext!;

Future<_Calls> _pumpHost(WidgetTester t, Size size) async {
  _setSize(t, size);
  await t.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: SizedBox.expand(key: _hostKey)),
    ),
  );
  return _Calls();
}

Future<void> _openPopover(WidgetTester t, _Calls calls) async {
  unawaited(
    showNavigatorPopover(
      _ctx,
      title: _title,
      total: _total,
      index: 5,
      answered: _answered,
      marked: const {2, 8},
      onJumpTo: calls.jumps.add,
      submitLabel: 'Submit quiz',
      onSubmitPressed: () => calls.submitPresses++,
    ),
  );
  await t.pumpAndSettle();
}

Future<void> _openSheet(WidgetTester t, _Calls calls) async {
  unawaited(
    showNavigatorSheet(
      _ctx,
      title: _title,
      total: _total,
      index: 5,
      answered: _answered,
      marked: const {2, 8},
      onJumpTo: calls.jumps.add,
      submitLabel: 'Submit quiz',
      onSubmitPressed: () => calls.submitPresses++,
    ),
  );
  await t.pumpAndSettle();
}

Future<void> _openSubmitDialog(WidgetTester t, _Calls calls) async {
  unawaited(
    showSubmitConfirmDialog(
      _ctx,
      title: 'Submit quiz?',
      body: 'After you submit, your answers are locked and marked.',
      confirmLabel: 'Submit quiz',
      total: _total,
      answered: _answered,
      onSubmit: () => calls.submits++,
      onJumpTo: calls.jumps.add,
    ),
  );
  await t.pumpAndSettle();
}

Future<void> _openTimeUp(
  WidgetTester t,
  _Calls calls, {
  int answered = 9,
}) async {
  unawaited(
    showQuizTimeUpDialog(
      _ctx,
      title: 'Quiz 4.2',
      answered: answered,
      onContinue: () => calls.continues++,
    ),
  );
  await t.pumpAndSettle();
}

Finder _cell(int i) => find.byKey(ValueKey('nav-cell-$i'));
final Finder _dialog = find.byType(BookletDialog);
Finder _inDialog(Finder f) => find.descendant(of: _dialog, matching: f);
final Finder _grid = find.byType(QuestionNavigatorGrid);

void _expectLegend() {
  for (final label in _legend) {
    expect(find.text(label), findsOneWidget, reason: label);
  }
}

void _expectOnlyTimeUpOpen() {
  expect(_dialog, findsOneWidget);
  expect(find.byType(QuestionNavigatorGrid), findsNothing);
  expect(find.byType(BottomSheet), findsNothing);
  expect(find.text('Submit quiz?'), findsNothing);
  expect(find.text("Time's up. Quiz 4.2 submitted."), findsOneWidget);
}

Future<void> _expectTimeUpIsModal(WidgetTester t, _Calls calls) async {
  await t.tapAt(const Offset(4, 4));
  await t.pumpAndSettle();
  expect(_dialog, findsOneWidget);

  await t.binding.handlePopRoute();
  await t.pumpAndSettle();
  expect(_dialog, findsOneWidget);
  expect(calls.continues, 0);
}

void main() {
  group('navigator popover', () {
    testWidgets('F-4: opens above the footer, within max width, 7 columns', (
      t,
    ) async {
      final calls = await _pumpHost(t, _wide);
      await _openPopover(t, calls);

      expect(find.text(_title), findsOneWidget);
      final popover = find
          .ancestor(of: _grid, matching: find.byType(Material))
          .first;
      final rect = t.getRect(popover);
      expect(rect.width, lessThanOrEqualTo(BookletSize.navigatorPopover));
      expect(
        rect.bottom,
        lessThanOrEqualTo(_wide.height - BookletSize.footerHeight),
      );
      expect(
        rect.bottom,
        closeTo(
          _wide.height - BookletSize.footerHeight - BookletSpace.s3,
          0.5,
        ),
      );
      expect(t.getCenter(popover).dx, closeTo(_wide.width / 2, 0.5));

      expect(t.getTopLeft(_cell(6)).dy, t.getTopLeft(_cell(0)).dy);
      expect(
        t.getTopLeft(_cell(7)).dy,
        greaterThan(t.getTopLeft(_cell(0)).dy),
      );
    });

    testWidgets('F-4: tapping the barrier closes it', (t) async {
      final calls = await _pumpHost(t, _wide);
      await _openPopover(t, calls);

      await t.tapAt(const Offset(4, 4));
      await t.pumpAndSettle();

      expect(_grid, findsNothing);
      expect(calls.jumps, isEmpty);
    });

    testWidgets('F-4: Esc closes it', (t) async {
      final calls = await _pumpHost(t, _wide);
      await _openPopover(t, calls);

      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pumpAndSettle();

      expect(_grid, findsNothing);
    });

    testWidgets('F-4: the close button closes it', (t) async {
      final calls = await _pumpHost(t, _wide);
      await _openPopover(t, calls);

      await t.tap(find.byTooltip('Close navigator'));
      await t.pumpAndSettle();

      expect(_grid, findsNothing);
      expect(calls.jumps, isEmpty);
    });

    testWidgets('F-4: tapping a cell pops and calls onJumpTo once', (t) async {
      final calls = await _pumpHost(t, _wide);
      await _openPopover(t, calls);

      await t.tap(_cell(11));
      await t.pumpAndSettle();

      expect(calls.jumps, [11]);
      expect(_grid, findsNothing);
    });

    testWidgets('F-4: Submit quiz pops and calls onSubmitPressed once', (
      t,
    ) async {
      final calls = await _pumpHost(t, _wide);
      await _openPopover(t, calls);

      await t.tap(find.text('Submit quiz'));
      await t.pumpAndSettle();

      expect(calls.submitPresses, 1);
      expect(calls.jumps, isEmpty);
      expect(_grid, findsNothing);
    });

    testWidgets('F-4: legend shows 4 entries', (t) async {
      final calls = await _pumpHost(t, _wide);
      await _openPopover(t, calls);
      _expectLegend();
    });
  });

  group('navigator sheet', () {
    testWidgets('F-4: has 6 columns, close sheet and no popover close', (
      t,
    ) async {
      final calls = await _pumpHost(t, _phone);
      await _openSheet(t, calls);

      expect(find.text(_title), findsOneWidget);
      expect(find.byTooltip('Close sheet'), findsOneWidget);
      expect(find.byTooltip('Close navigator'), findsNothing);
      expect(t.getTopLeft(_cell(5)).dy, t.getTopLeft(_cell(0)).dy);
      expect(
        t.getTopLeft(_cell(6)).dy,
        greaterThan(t.getTopLeft(_cell(0)).dy),
      );
    });

    testWidgets('F-4: tapping a cell pops and calls onJumpTo once', (t) async {
      final calls = await _pumpHost(t, _phone);
      await _openSheet(t, calls);

      await t.tap(_cell(11));
      await t.pumpAndSettle();

      expect(calls.jumps, [11]);
      expect(_grid, findsNothing);
    });

    testWidgets('F-4: Submit quiz pops and calls onSubmitPressed once', (
      t,
    ) async {
      final calls = await _pumpHost(t, _phone);
      await _openSheet(t, calls);

      await t.tap(find.text('Submit quiz'));
      await t.pumpAndSettle();

      expect(calls.submitPresses, 1);
      expect(_grid, findsNothing);
    });

    testWidgets('F-4: legend shows 4 entries', (t) async {
      final calls = await _pumpHost(t, _phone);
      await _openSheet(t, calls);
      _expectLegend();
    });
  });

  testWidgets('F-4: NavigatorLegend alone shows 4 entries', (t) async {
    _setSize(t, _wide);
    await t.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(body: NavigatorLegend()),
      ),
    );
    _expectLegend();
  });

  group('submit confirm dialog with quiz copy', () {
    testWidgets('F-4: shows title, body, chips and both actions', (t) async {
      final calls = await _pumpHost(t, _wide);
      await _openSubmitDialog(t, calls);

      expect(t.widget<BookletDialog>(_dialog).title, 'Submit quiz?');
      expect(
        _inDialog(
          find.text('After you submit, your answers are locked and marked.'),
        ),
        findsOneWidget,
      );
      for (final chip in _unansweredChips) {
        expect(_inDialog(find.text(chip)), findsOneWidget);
      }
      expect(_inDialog(find.text('Q1')), findsNothing);
      expect(_inDialog(find.text('Keep working')), findsOneWidget);
      expect(_inDialog(find.text('Submit quiz')), findsOneWidget);
    });

    testWidgets('F-4: confirming pops and calls onSubmit once', (t) async {
      final calls = await _pumpHost(t, _wide);
      await _openSubmitDialog(t, calls);

      await t.tap(_inDialog(find.text('Submit quiz')));
      await t.pumpAndSettle();

      expect(calls.submits, 1);
      expect(calls.jumps, isEmpty);
      expect(_dialog, findsNothing);
    });

    testWidgets('F-4: tapping a chip pops and jumps to that question', (
      t,
    ) async {
      final calls = await _pumpHost(t, _wide);
      await _openSubmitDialog(t, calls);

      await t.tap(_inDialog(find.text('Q14')));
      await t.pumpAndSettle();

      expect(calls.jumps, [13]);
      expect(calls.submits, 0);
      expect(_dialog, findsNothing);
    });
  });

  group('time-up dialog replaces open overlays', () {
    testWidgets('F-4: with the popover open leaves exactly one dialog', (
      t,
    ) async {
      final calls = await _pumpHost(t, _wide);
      await _openPopover(t, calls);
      await _openTimeUp(t, calls);

      _expectOnlyTimeUpOpen();
      await _expectTimeUpIsModal(t, calls);
      expect(calls.jumps, isEmpty);
      expect(calls.submitPresses, 0);
    });

    testWidgets('F-4: with the sheet open leaves exactly one dialog', (
      t,
    ) async {
      final calls = await _pumpHost(t, _phone);
      await _openSheet(t, calls);
      await _openTimeUp(t, calls);

      _expectOnlyTimeUpOpen();
      await _expectTimeUpIsModal(t, calls);
      expect(calls.jumps, isEmpty);
      expect(calls.submitPresses, 0);
    });

    testWidgets('F-4: with the submit dialog open leaves exactly one dialog', (
      t,
    ) async {
      final calls = await _pumpHost(t, _wide);
      await _openSubmitDialog(t, calls);
      await _openTimeUp(t, calls);

      _expectOnlyTimeUpOpen();
      await _expectTimeUpIsModal(t, calls);
      expect(calls.submits, 0);
    });

    testWidgets('F-4: with nothing open it opens by itself', (t) async {
      final calls = await _pumpHost(t, _wide);
      await _openTimeUp(t, calls);

      _expectOnlyTimeUpOpen();
    });

    testWidgets('F-4: Continue fires once and closes it', (t) async {
      final calls = await _pumpHost(t, _wide);
      await _openPopover(t, calls);
      await _openTimeUp(t, calls);

      await t.tap(_inDialog(find.text('Continue')));
      await t.pumpAndSettle();

      expect(calls.continues, 1);
      expect(_dialog, findsNothing);
    });
  });

  group('time-up copy', () {
    testWidgets('F-4: singular answer', (t) async {
      final calls = await _pumpHost(t, _wide);
      await _openTimeUp(t, calls, answered: 1);

      expect(
        find.text(
          'Your 1 answer was saved and submitted automatically. '
          'Unanswered questions count as incorrect.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('F-4: plural answers', (t) async {
      final calls = await _pumpHost(t, _wide);
      await _openTimeUp(t, calls);

      expect(
        find.text(
          'Your 9 answers were saved and submitted automatically. '
          'Unanswered questions count as incorrect.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('F-4: title, schedule icon and Continue action', (t) async {
      final calls = await _pumpHost(t, _wide);
      await _openTimeUp(t, calls);

      expect(
        t.widget<BookletDialog>(_dialog).title,
        "Time's up. Quiz 4.2 submitted.",
      );
      expect(_inDialog(find.byIcon(Icons.schedule)), findsOneWidget);
      expect(_inDialog(find.text('Continue')), findsOneWidget);
    });
  });
}
