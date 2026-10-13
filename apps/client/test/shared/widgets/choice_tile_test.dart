import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/theme/app_theme.dart';
import 'package:sat_east_client/core/theme/booklet_tokens.dart';
import 'package:sat_east_client/shared/widgets/choice_tile.dart';
import 'package:sat_east_client/shared/widgets/focus_ring.dart';

Future<void> pumpTile(
  WidgetTester tester,
  ChoiceTile tile, {
  double width = 720,
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
        child: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(BookletSpace.s4),
            child: Column(children: [tile]),
          ),
        ),
      ),
    ),
  );
}

ChoiceTile tile(
  ChoiceTileState state, {
  VoidCallback? onSelect,
  VoidCallback? onEliminate,
  VoidCallback? onRestore,
  String content = r'\(x = 3\)',
}) => ChoiceTile(
  letter: 'B',
  content: content,
  state: state,
  onSelect: onSelect,
  onEliminate: onEliminate,
  onRestore: onRestore,
);

void main() {
  testWidgets('F-4: tapping an idle tile selects it', (t) async {
    var taps = 0;
    await pumpTile(t, tile(ChoiceTileState.idle, onSelect: () => taps++));
    await t.tap(find.byType(ChoiceTile));
    expect(taps, 1);
  });

  testWidgets('F-4: cross-out fires onEliminate, not onSelect', (t) async {
    var selects = 0;
    var eliminates = 0;
    await pumpTile(
      t,
      tile(
        ChoiceTileState.selected,
        onSelect: () => selects++,
        onEliminate: () => eliminates++,
      ),
    );
    await t.tap(find.byTooltip('Cross out choice B'));
    expect((selects, eliminates), (0, 1));
  });

  testWidgets('F-4: cross-out target is 48 px', (t) async {
    await pumpTile(
      t,
      tile(ChoiceTileState.idle, onSelect: () {}, onEliminate: () {}),
    );
    final size = t.getSize(find.byType(IconButton));
    expect(size.width, greaterThanOrEqualTo(BookletSize.touchTarget));
    expect(size.height, greaterThanOrEqualTo(BookletSize.touchTarget));
  });

  testWidgets('F-4: no cross-out without onEliminate', (t) async {
    await pumpTile(t, tile(ChoiceTileState.idle, onSelect: () {}));
    expect(find.byType(IconButton), findsNothing);
  });

  testWidgets('F-4: eliminated tile restores via Undo and ignores taps', (
    t,
  ) async {
    var selects = 0;
    var restores = 0;
    await pumpTile(
      t,
      tile(
        ChoiceTileState.eliminated,
        onSelect: () => selects++,
        onRestore: () => restores++,
      ),
    );
    await t.tap(find.text('Undo'));
    await t.tapAt(t.getTopLeft(find.byType(ChoiceTile)) + const Offset(40, 20));
    expect((selects, restores), (0, 1));
  });

  testWidgets('F-4: disabled tile ignores taps and has no cross-out', (
    t,
  ) async {
    var selects = 0;
    await pumpTile(
      t,
      tile(
        ChoiceTileState.disabled,
        onSelect: () => selects++,
        onEliminate: () {},
      ),
    );
    await t.tap(find.byType(ChoiceTile));
    expect(selects, 0);
    expect(find.byType(IconButton), findsNothing);
  });

  testWidgets('F-4: keyboard Tab shows the ring and Enter selects', (t) async {
    var selects = 0;
    await pumpTile(t, tile(ChoiceTileState.idle, onSelect: () => selects++));
    await t.sendKeyEvent(LogicalKeyboardKey.tab);
    await t.pump();
    expect(t.widget<FocusRing>(find.byType(FocusRing)).visible, isTrue);
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(selects, 1);
  });

  testWidgets('F-4: tile size is the same across states', (t) async {
    Future<Size> sizeOf(ChoiceTileState s) async {
      await pumpTile(t, tile(s, onSelect: () {}, onEliminate: () {}));
      return t.getSize(find.byType(ChoiceTile));
    }

    final idle = await sizeOf(ChoiceTileState.idle);
    expect(await sizeOf(ChoiceTileState.selected), idle);
    expect((await sizeOf(ChoiceTileState.correct)).height, idle.height);
    expect((await sizeOf(ChoiceTileState.correctAnswer)).height, idle.height);
  });

  for (final (state, label, icon) in [
    (ChoiceTileState.correct, 'Correct', Icons.check_circle_rounded),
    (ChoiceTileState.incorrect, 'Incorrect', Icons.cancel_rounded),
    (ChoiceTileState.yourAnswerWrong, 'Your answer', Icons.cancel_rounded),
    (
      ChoiceTileState.correctAnswer,
      'Correct answer',
      Icons.check_circle_outline_rounded,
    ),
    (
      ChoiceTileState.yourAnswerCorrect,
      'Your answer · Correct',
      Icons.check_circle_rounded,
    ),
  ]) {
    testWidgets('F-4: ${state.name} shows "$label"', (t) async {
      await pumpTile(t, tile(state, onSelect: () {}, onEliminate: () {}));
      expect(find.text(label), findsOneWidget);
      expect(find.byIcon(icon), findsOneWidget);
      expect(find.byType(IconButton), findsNothing);
    });
  }

  testWidgets('F-4: selected tile is a checked radio', (t) async {
    final handle = t.ensureSemantics();
    await pumpTile(t, tile(ChoiceTileState.selected, onSelect: () {}));
    expect(
      t.getSemantics(find.byType(ChoiceTile)),
      isSemantics(
        isInMutuallyExclusiveGroup: true,
        hasCheckedState: true,
        isChecked: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('F-4: two-line choice at 360 px and 2x text does not overflow', (
    t,
  ) async {
    await pumpTile(
      t,
      tile(
        ChoiceTileState.idle,
        onSelect: () {},
        onEliminate: () {},
        content:
            r'The line rises 3 units for each unit to the right, so its slope is \(3\).',
      ),
      width: 360,
      textScale: 2,
    );
    expect(t.takeException(), isNull);
    expect(
      t.getSize(find.byType(IconButton)).height,
      greaterThanOrEqualTo(BookletSize.touchTarget),
    );
  });
}
