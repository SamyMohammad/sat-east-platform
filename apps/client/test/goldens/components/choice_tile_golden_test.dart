@Tags(['golden'])
library;

import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:sat_east_client/core/theme/app_tokens.dart';
import 'package:sat_east_client/shared/widgets/choice_tile.dart';

import '../golden_harness.dart';

const _rows = <(ChoiceTileState, String)>[
  (ChoiceTileState.idle, r'\(x = -3\)'),
  (ChoiceTileState.selected, r'\(\frac{3}{4}\)'),
  (ChoiceTileState.eliminated, r'\(x = 9\)'),
  (ChoiceTileState.disabled, r'\(x = -3\)'),
  (
    ChoiceTileState.idle,
    r'The line rises 3 units for each unit to the right, so its slope is \(3\).',
  ),
  (ChoiceTileState.idle, r'The slope of the line is \(3\).'),
  (ChoiceTileState.correct, r'\(\frac{3}{4}\)'),
  (ChoiceTileState.incorrect, r'\(x = -3\)'),
  (ChoiceTileState.yourAnswerWrong, r'\(x = 15\)'),
  (ChoiceTileState.correctAnswer, r'\(x = 3\)'),
  (ChoiceTileState.yourAnswerCorrect, r'\(x = 3\)'),
  (ChoiceTileState.reviewOther, r'\(x = \frac{3}{5}\)'),
];

Widget _sheet() => Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  spacing: AppSpace.s3,
  children: [
    for (final (i, (state, content)) in _rows.indexed)
      ChoiceTile(
        letter: 'ABCD'[i % 4],
        content: content,
        state: state,
        onSelect: () {},
        onEliminate: () {},
        onRestore: () {},
      ),
  ],
);

void main() {
  for (final width in goldenWidths) {
    for (final brightness in Brightness.values) {
      final name = 'choice_tile_${brightness.name}_${width.toInt()}';
      testWidgets('F-4: golden $name', (t) async {
        await expectGolden(
          t,
          name: name,
          child: _sheet(),
          width: width,
          brightness: brightness,
        );
      });
    }
  }

  testWidgets('F-4: golden choice_tile_light_360_text2x', (t) async {
    await expectGolden(
      t,
      name: 'choice_tile_light_360_text2x',
      child: _sheet(),
      width: 360,
      textScale: 2,
    );
  });
}
