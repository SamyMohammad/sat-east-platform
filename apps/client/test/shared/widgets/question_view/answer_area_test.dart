import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:sat_east_client/core/theme/app_theme.dart';
import 'package:sat_east_client/shared/widgets/choice_tile.dart';
import 'package:sat_east_client/shared/widgets/question_view/answer_state.dart';
import 'package:sat_east_client/shared/widgets/question_view/parts/choice_list.dart';
import 'package:sat_east_client/shared/widgets/question_view/parts/spr_answer_area.dart';
import 'package:sat_east_client/shared/widgets/question_view/practice_feedback.dart';
import 'package:sat_east_client/shared/widgets/question_view/question_data.dart';
import 'package:sat_east_client/shared/widgets/question_view/question_view_mode.dart';
import 'package:sat_east_client/shared/widgets/spr_input.dart';
import 'package:sat_east_client/shared/widgets/spr_keypad.dart';

const _choices = [
  ChoiceData(label: 'A', md: 'one'),
  ChoiceData(label: 'B', md: 'two'),
  ChoiceData(label: 'C', md: 'three'),
];

const _idleMode = PracticeMode(feedback: Idle(), rep: 1, repTarget: 3);

typedef ChoiceCalls = ({
  List<String> selects,
  List<String> eliminates,
  List<String> restores,
});

Future<ChoiceCalls> pumpChoices(
  WidgetTester t, {
  required bool interactive,
  AnswerState answer = const AnswerState(),
}) async {
  final selects = <String>[];
  final eliminates = <String>[];
  final restores = <String>[];
  t.view.physicalSize = const Size(720, 1600);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: ChoiceList(
            choices: _choices,
            answer: answer,
            mode: _idleMode,
            interactive: interactive,
            onSelect: selects.add,
            onEliminate: eliminates.add,
            onRestore: restores.add,
          ),
        ),
      ),
    ),
  );
  return (selects: selects, eliminates: eliminates, restores: restores);
}

Future<List<String>> pumpSpr(
  WidgetTester t, {
  required bool useKeypad,
  String initial = '',
  SprInputState state = SprInputState.editable,
  String? correctAnswer,
}) async {
  final changes = <String>[];
  var text = initial;
  t.view.physicalSize = const Size(360, 800);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) => SingleChildScrollView(
            child: SprAnswerArea(
              text: text,
              state: state,
              useKeypad: useKeypad,
              correctAnswer: correctAnswer,
              onChanged: (value) {
                changes.add(value);
                setState(() => text = value);
              },
            ),
          ),
        ),
      ),
    ),
  );
  return changes;
}

String _fieldText(WidgetTester t) =>
    t.widget<TextField>(find.byType(TextField)).controller!.text;

void main() {
  group('ChoiceList', () {
    testWidgets('F-4: tapping a tile fires onSelect with its label', (t) async {
      final calls = await pumpChoices(t, interactive: true);
      await t.tap(find.byType(ChoiceTile).at(1));
      expect(calls.selects, ['B']);
      expect(calls.eliminates, isEmpty);
      expect(calls.restores, isEmpty);
    });

    testWidgets('F-4: cross-out fires onEliminate with its label', (t) async {
      final calls = await pumpChoices(t, interactive: true);
      await t.tap(find.byTooltip('Cross out choice C'));
      expect(calls.eliminates, ['C']);
      expect(calls.selects, isEmpty);
    });

    testWidgets('F-4: Undo on an eliminated tile fires onRestore', (t) async {
      final calls = await pumpChoices(
        t,
        interactive: true,
        answer: const AnswerState(eliminated: {'B'}),
      );
      await t.tap(find.text('Undo'));
      expect(calls.restores, ['B']);
      expect(calls.selects, isEmpty);
    });

    testWidgets('F-4: non-interactive tiles fire nothing', (t) async {
      final calls = await pumpChoices(
        t,
        interactive: false,
        answer: const AnswerState(eliminated: {'B'}),
      );
      await t.tap(find.byType(ChoiceTile).first, warnIfMissed: false);
      expect(find.byTooltip('Cross out choice A'), findsNothing);
      expect(find.text('Undo'), findsNothing);
      expect(calls.selects, isEmpty);
      expect(calls.eliminates, isEmpty);
      expect(calls.restores, isEmpty);
    });
  });

  group('SprAnswerArea', () {
    testWidgets('F-4: keypad keys 3, slash, slash give "3/" and a hint', (
      t,
    ) async {
      await pumpSpr(t, useKeypad: true);
      await t.tap(find.text('3'));
      await t.pump();
      await t.tap(find.text('/'));
      await t.pump();
      expect(_fieldText(t), '3/');
      await t.tap(find.text('/'));
      await t.pump();
      expect(_fieldText(t), '3/');
      expect(find.text('A fraction has only one slash.'), findsOneWidget);
    });

    testWidgets('F-4: hardware typing clears the keypad key hint', (t) async {
      await pumpSpr(t, useKeypad: true);
      await t.tap(find.text('3'));
      await t.pump();
      await t.tap(find.text('/'));
      await t.pump();
      await t.tap(find.text('/'));
      await t.pump();
      await t.pump();
      expect(find.text('A fraction has only one slash.'), findsOneWidget);
      await t.enterText(find.byType(TextField), '3/4');
      await t.pump();
      expect(find.text('A fraction has only one slash.'), findsNothing);
    });

    testWidgets('F-4: Hide removes the keypad and tapping the field shows it', (
      t,
    ) async {
      await pumpSpr(t, useKeypad: true);
      expect(find.byType(SprKeypad), findsOneWidget);
      await t.tap(find.bySemanticsLabel('Hide keypad'));
      await t.pump();
      expect(find.byType(SprKeypad), findsNothing);
      await t.tap(find.byType(TextField));
      await t.pump();
      expect(find.byType(SprKeypad), findsOneWidget);
    });

    testWidgets('F-4: useKeypad passes through to the SprInput', (t) async {
      await pumpSpr(t, useKeypad: true);
      expect(
        find.byWidgetPredicate((w) => w is SprInput && w.useKeypad),
        findsOneWidget,
      );
    });

    testWidgets('F-4: without useKeypad no SprKeypad appears', (t) async {
      await pumpSpr(t, useKeypad: false);
      expect(find.byType(SprKeypad), findsNothing);
      expect(find.byType(SprInput), findsOneWidget);
    });

    testWidgets('F-4: incorrect state shows the passed correctAnswer', (
      t,
    ) async {
      await pumpSpr(
        t,
        useKeypad: false,
        initial: '15',
        state: SprInputState.incorrect,
        correctAnswer: '3/4',
      );
      expect(find.textContaining('Correct answer: 3/4'), findsOneWidget);
    });

    testWidgets('F-4: editable state passes no correctAnswer to SprInput', (
      t,
    ) async {
      await pumpSpr(t, useKeypad: false, initial: '15');
      expect(
        find.byWidgetPredicate((w) => w is SprInput && w.correctAnswer == null),
        findsOneWidget,
      );
      expect(find.textContaining('Correct answer:'), findsNothing);
    });
  });
}
