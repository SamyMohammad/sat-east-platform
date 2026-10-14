import 'package:flutter/material.dart';

import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sat_east_client/core/grading/spr_editing.dart';
import 'package:sat_east_client/core/theme/app_theme.dart';
import 'package:sat_east_client/shared/widgets/spr_input.dart';

Future<List<String>> pumpSpr(
  WidgetTester tester, {
  String value = '',
  SprInputState state = SprInputState.editable,
  SprKeyHint? keyHint,
  String? correctAnswer,
  bool useKeypad = false,
  FocusNode? focusNode,
  VoidCallback? onSubmitted,
  double width = 720,
  double textScale = 1,
}) async {
  final changes = <String>[];
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: MediaQuery.withClampedTextScaling(
          minScaleFactor: textScale,
          maxScaleFactor: textScale,
          child: SprInput(
            value: value,
            onChanged: changes.add,
            state: state,
            keyHint: keyHint,
            correctAnswer: correctAnswer,
            useKeypad: useKeypad,
            focusNode: focusNode,
            onSubmitted: onSubmitted,
          ),
        ),
      ),
    ),
  );
  return changes;
}

void main() {
  TextEditingValue formatEdit(TextEditingValue edit) => sprInputFormatters.fold(
    edit,
    (value, formatter) => formatter.formatEditUpdate(
      TextEditingValue.empty,
      value,
    ),
  );

  test('F-4: committed Persian digits decimal and minus become ASCII', () {
    const edit = TextEditingValue(
      text: '−۱۲٫۵',
      selection: TextSelection.collapsed(offset: 5),
    );
    final formatted = formatEdit(edit);
    expect(formatted.text, '-12.5');
    expect(formatted.selection, edit.selection);
  });

  test('F-4: formatter caps committed input above the grading limit', () {
    final formatted = formatEdit(
      const TextEditingValue(
        text: '123456789012',
        selection: TextSelection.collapsed(offset: 12),
      ),
    );
    expect(formatted.text, '12345678');
    expect(formatted.selection.baseOffset, sprInputMaxChars);
  });

  test(
    'F-4: formatter preserves seven characters so length hints can show',
    () {
      final formatted = formatEdit(
        const TextEditingValue(
          text: '0.66667',
          selection: TextSelection.collapsed(offset: 7),
        ),
      );
      expect(formatted.text, '0.66667');
      expect(sprHintText(formatted.text), contains('Up to 5 characters'));
    },
  );

  test('F-4: active IME composition stays untouched until committed', () {
    const composing = TextEditingValue(
      text: '−۱۲٫۵abc123456789',
      selection: TextSelection.collapsed(offset: 17),
      composing: TextRange(start: 0, end: 17),
    );
    expect(formatEdit(composing), composing);

    final committed = formatEdit(
      composing.copyWith(composing: TextRange.empty),
    );
    expect(committed.text, '-12.5123');
    expect(committed.composing, TextRange.empty);
  });

  testWidgets('F-4: empty field shows placeholder and format helper', (
    t,
  ) async {
    await pumpSpr(t);
    expect(find.text('Your answer'), findsOneWidget);
    expect(find.text('Type answer'), findsOneWidget);
    expect(find.text('Fraction, decimal or integer'), findsOneWidget);
  });

  testWidgets('F-4: desktop input decoration stays '
      '200 by 56 pixels', (
    t,
  ) async {
    await pumpSpr(t);

    expect(t.getSize(find.byType(InputDecorator)), const Size(200, 56));
    expect(t.takeException(), isNull);
  });

  testWidgets('F-4: typing reports the text', (t) async {
    final changes = await pumpSpr(t);
    await t.enterText(find.byType(TextField), '-3/4');
    expect(changes.last, '-3/4');
  });

  testWidgets('F-4: a valid value shows the Answer preview', (t) async {
    await pumpSpr(t, value: '-3/4');
    expect(find.text('Answer preview'), findsOneWidget);
    expect(find.byType(Math), findsOneWidget);
  });

  testWidgets('F-4: laptop answer preview sits beside the field', (t) async {
    await pumpSpr(t, value: '-3/4', width: 1280);

    final field = t.getRect(find.byType(TextField));
    final preview = t.getRect(find.text('Answer preview'));
    expect(preview.left, greaterThan(field.right));
    expect(preview.top, lessThan(field.bottom));
    expect(preview.bottom, greaterThan(field.top));
    expect(t.takeException(), isNull);
  });

  testWidgets('F-4: incomplete value shows the preview helper, no preview', (
    t,
  ) async {
    await pumpSpr(t, value: '3/');
    expect(
      find.text("Answer preview appears when it's a number"),
      findsOneWidget,
    );
    expect(find.text('Answer preview'), findsNothing);
  });

  for (final (value, phrase) in [
    ('1 1/2', "Mixed numbers aren't accepted"),
    ('0.66667', 'Up to 5 characters'),
    ('3/0', "can't have 0"),
  ]) {
    testWidgets('F-4: "$value" shows an info hint', (t) async {
      await pumpSpr(t, value: value);
      expect(find.textContaining(phrase), findsOneWidget);
      expect(find.byIcon(Icons.info_outline_rounded), findsOneWidget);
    });
  }

  testWidgets(
    'F-4: the field accepts a space and 7 characters (hints reachable)',
    (t) async {
      final changes = await pumpSpr(t);
      await t.enterText(find.byType(TextField), '1 1/2');
      expect(changes.last, '1 1/2');
      await t.enterText(find.byType(TextField), '0.66667');
      expect(changes.last, '0.66667');
    },
  );

  testWidgets('F-4: keypad hint wins over parse hints', (t) async {
    await pumpSpr(t, value: '3/4', keyHint: SprKeyHint.secondSlash);
    expect(find.textContaining('only one'), findsOneWidget);
  });

  testWidgets('F-4: Arabic-Indic digits are normalised to ASCII', (t) async {
    final changes = await pumpSpr(t);
    await t.enterText(find.byType(TextField), '٣/٤');
    expect(changes.last, '3/4');
  });

  testWidgets('F-4: letters are filtered out', (t) async {
    final changes = await pumpSpr(t);
    await t.enterText(find.byType(TextField), '12abc');
    expect(changes.last, '12');
  });

  testWidgets('F-4: parent value updates the field', (t) async {
    await pumpSpr(t, value: '1');
    await pumpSpr(t, value: '12');
    final field = t.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, '12');
    expect(field.controller!.selection.baseOffset, 2);
  });

  testWidgets(
    'F-4: parent value updates the preview without firing onChanged',
    (t) async {
      await pumpSpr(t, value: '3/');
      final changes = await pumpSpr(t, value: '3/4');
      expect(find.text('Answer preview'), findsOneWidget);
      expect(find.byType(Math), findsOneWidget);
      expect(changes, isEmpty);
    },
  );

  testWidgets('F-4: rejected edits reset to the parent value on rebuild', (
    t,
  ) async {
    await pumpSpr(t, value: '1');
    await t.enterText(find.byType(TextField), '12');
    await pumpSpr(t, value: '1');
    expect(t.widget<TextField>(find.byType(TextField)).controller!.text, '1');
  });

  testWidgets('F-4: submission calls the parent once', (t) async {
    var submits = 0;
    await pumpSpr(t, value: '12', onSubmitted: () => submits++);
    await t.showKeyboard(find.byType(TextField));
    await t.testTextInput.receiveAction(TextInputAction.done);
    expect(submits, 1);
  });

  testWidgets('F-4: externally owned focus node survives unmount', (t) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await pumpSpr(t, focusNode: focus);
    focus.requestFocus();
    await t.pump();
    expect(focus.hasFocus, isTrue);
    await t.pumpWidget(const SizedBox());
    void listener() {}
    expect(() => focus.addListener(listener), returnsNormally);
    focus.removeListener(listener);
  });

  testWidgets(
    'F-4: replacing external focus node and returning to owned focus is safe',
    (t) async {
      final first = FocusNode();
      final second = FocusNode();
      addTearDown(first.dispose);
      addTearDown(second.dispose);
      await pumpSpr(t, focusNode: first);
      await pumpSpr(t, focusNode: second);
      second.requestFocus();
      await t.pump();
      expect(second.hasFocus, isTrue);
      expect(first.hasFocus, isFalse);
      await pumpSpr(t);
      await t.tap(find.byType(TextField));
      await t.pump();
      expect(
        t.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus,
        isTrue,
      );
      expect(t.takeException(), isNull);
    },
  );

  testWidgets('F-4: owned focus can be replaced by an external node', (
    t,
  ) async {
    final external = FocusNode();
    addTearDown(external.dispose);
    await pumpSpr(t);
    await pumpSpr(t, focusNode: external);
    external.requestFocus();
    await t.pump();
    expect(external.hasFocus, isTrue);
    expect(t.takeException(), isNull);
  });

  testWidgets('F-4: disabled field is not editable', (t) async {
    await pumpSpr(t, value: '12', state: SprInputState.disabled);
    expect(t.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    expect(find.text('Fraction, decimal or integer'), findsNothing);
  });

  testWidgets('F-4: keypad mode keeps the system keyboard down', (t) async {
    await pumpSpr(t, useKeypad: true);
    expect(
      t.widget<TextField>(find.byType(TextField)).keyboardType,
      TextInputType.none,
    );
  });

  testWidgets('F-4: review correct shows the value and Correct', (t) async {
    await pumpSpr(t, value: '12', state: SprInputState.correct);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('Correct'), findsOneWidget);
  });

  testWidgets('F-4: review incorrect shows the correct answer', (t) async {
    await pumpSpr(
      t,
      value: '15',
      state: SprInputState.incorrect,
      correctAnswer: '3',
    );
    expect(find.text('Incorrect'), findsOneWidget);
    expect(find.textContaining('Correct answer: 3'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('15'), findsOneWidget);
  });

  for (final state in [
    SprInputState.editable,
    SprInputState.disabled,
    SprInputState.correct,
  ]) {
    testWidgets('F-4: ${state.name} does not reveal the correct answer', (
      t,
    ) async {
      await pumpSpr(t, value: '15', state: state, correctAnswer: '3');
      expect(find.textContaining('Correct answer:'), findsNothing);
    });
  }

  for (final (state, value) in [
    (SprInputState.editable, '-3/4'),
    (SprInputState.editable, '1 1/2'),
    (SprInputState.correct, '12'),
    (SprInputState.incorrect, '15'),
  ]) {
    testWidgets('F-4: ${state.name} value $value fits 360 px at 2x text', (
      t,
    ) async {
      await pumpSpr(
        t,
        value: value,
        state: state,
        correctAnswer: '-3/4',
        width: 360,
        textScale: 2,
      );
      expect(t.takeException(), isNull);
    });
  }

  test('F-4: sprHintText maps each refusal to copy', () {
    expect(
      sprHintText('3/4', keyHint: SprKeyHint.secondDot),
      contains('decimal point'),
    );
    expect(
      sprHintText('1.5', keyHint: SprKeyHint.slashAndDot),
      contains('not both'),
    );
    expect(sprHintText('12'), isNull);
    expect(sprHintText('3/'), isNull);
  });
}
