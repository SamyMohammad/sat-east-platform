@Tags(['golden'])
library;

import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:sat_east_client/core/grading/spr_editing.dart';
import 'package:sat_east_client/core/theme/app_tokens.dart';
import 'package:sat_east_client/shared/widgets/spr_input.dart';
import 'package:sat_east_client/shared/widgets/spr_keypad.dart';

import '../golden_harness.dart';

const _inputs = <(String, SprInputState, SprKeyHint?)>[
  ('', SprInputState.editable, null),
  ('3/', SprInputState.editable, null),
  ('-3/4', SprInputState.editable, null),
  ('1 1/2', SprInputState.editable, null),
  ('0.66667', SprInputState.editable, null),
  ('3/0', SprInputState.editable, null),
  ('3/4', SprInputState.editable, SprKeyHint.secondSlash),
  ('12', SprInputState.disabled, null),
  ('12', SprInputState.correct, null),
  ('15', SprInputState.incorrect, null),
];

Widget _inputSheet() => Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  spacing: AppSpace.s6,
  children: [
    for (final (value, state, hint) in _inputs)
      SprInput(
        value: value,
        onChanged: (_) {},
        state: state,
        keyHint: hint,
        correctAnswer: state == SprInputState.incorrect ? '3' : null,
      ),
  ],
);

void main() {
  for (final width in goldenWidths) {
    for (final brightness in Brightness.values) {
      final name = 'spr_input_${brightness.name}_${width.toInt()}';
      testWidgets('F-4: golden $name', (t) async {
        await expectGolden(
          t,
          name: name,
          child: _inputSheet(),
          width: width,
          brightness: brightness,
        );
      });
    }
  }

  for (final brightness in Brightness.values) {
    final name = 'spr_keypad_${brightness.name}_360';
    testWidgets('F-4: golden $name', (t) async {
      await expectGolden(
        t,
        name: name,
        child: SprKeypad(onKey: (_) {}, onHide: () {}),
        width: 360,
        brightness: brightness,
      );
    });
  }

  testWidgets('F-4: golden spr_input_light_360_text2x', (t) async {
    await expectGolden(
      t,
      name: 'spr_input_light_360_text2x',
      child: _inputSheet(),
      width: 360,
      textScale: 2,
    );
  });

  testWidgets('F-4: golden spr_keypad_light_360_text2x', (t) async {
    await expectGolden(
      t,
      name: 'spr_keypad_light_360_text2x',
      child: SprKeypad(onKey: (_) {}, onHide: () {}),
      width: 360,
      textScale: 2,
    );
  });
}
