import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:sat_east_client/core/theme/app_theme.dart';
import 'package:sat_east_client/shared/widgets/choice_tile.dart';
import 'package:sat_east_client/shared/widgets/loading_button.dart';
import 'package:sat_east_client/shared/widgets/question_view/answer_state.dart';
import 'package:sat_east_client/shared/widgets/question_view/parts/exercise_header.dart';
import 'package:sat_east_client/shared/widgets/question_view/parts/hint_panel.dart';
import 'package:sat_east_client/shared/widgets/question_view/parts/margin_note.dart';
import 'package:sat_east_client/shared/widgets/question_view/parts/worked_example.dart';
import 'package:sat_east_client/shared/widgets/question_view/practice_feedback.dart';
import 'package:sat_east_client/shared/widgets/question_view/question_data.dart';
import 'package:sat_east_client/shared/widgets/question_view/question_view.dart';
import 'package:sat_east_client/shared/widgets/question_view/question_view_mode.dart';
import 'package:sat_east_client/shared/widgets/spr_input.dart';

const _phone = Size(360, 800);
const _tablet = Size(768, 1024);
const _wide = Size(1280, 800);

const _choices = [
  ChoiceData(label: 'A', md: r'$x = 1$'),
  ChoiceData(label: 'B', md: r'$x = 2$'),
  ChoiceData(label: 'C', md: r'$x = 3$'),
  ChoiceData(label: 'D', md: r'$x = 4$'),
];

QuestionData _mcq({List<String> imagePaths = const []}) => QuestionData(
  id: 'q1',
  label: '4.2 · Ex 7',
  stemMd: r'Solve $2x + 3 = 7$.',
  kind: const McqKind(_choices),
  imagePaths: imagePaths,
);

QuestionData _spr(String id) => QuestionData(
  id: id,
  label: '4.2 · Ex 7',
  stemMd: r'Solve $4x = 3$.',
  kind: const SprKind(),
);

PracticeMode _mode(PracticeFeedback feedback, {String? author = 'Mr. Samy'}) =>
    PracticeMode(
      feedback: feedback,
      rep: 7,
      repTarget: 10,
      noteAuthor: author,
    );

Future<void> _setSize(WidgetTester t, Size size) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
}

Widget _app(Widget child) => MaterialApp(
  theme: AppTheme.light(),
  home: Scaffold(body: child),
);

Future<void> _pump(
  WidgetTester t, {
  required Size size,
  required PracticeFeedback feedback,
  QuestionData? question,
  AnswerState answer = const AnswerState(),
  VoidCallback? onCheck,
  VoidCallback? onNext,
  VoidCallback? onPrev,
  ValueChanged<String>? onSelect,
  Widget Function(BuildContext, String)? figureBuilder,
}) async {
  await _setSize(t, size);
  await t.pumpWidget(
    _app(
      QuestionView(
        title: 'Linear equations',
        question: question ?? _mcq(),
        mode: _mode(feedback),
        answer: answer,
        onCheck: onCheck,
        onNext: onNext,
        onPrev: onPrev,
        onSelect: onSelect,
        figureBuilder: figureBuilder,
      ),
    ),
  );
  await t.pump();
}

LoadingButton _button(WidgetTester t, String label) => t.widget<LoadingButton>(
  find.byWidgetPredicate((w) => w is LoadingButton && w.label == label),
);

ChoiceTile _tile(WidgetTester t, String label) =>
    t.widget<ChoiceTile>(find.byKey(ValueKey('choice-$label')));

Finder _inTile(String label, String text) => find.descendant(
  of: find.byKey(ValueKey('choice-$label')),
  matching: find.text(text),
);

MarginNote _note(WidgetTester t) => t.widget<MarginNote>(
  find.byType(MarginNote),
);

void main() {
  for (final size in [_phone, _wide]) {
    final w = size.width.toInt();

    group('QuestionView practice at $w', () {
      testWidgets('F-4: Idle shows the practice copy and header', (t) async {
        await _pump(t, size: size, feedback: const Idle());
        expect(find.text('Linear equations'), findsOneWidget);
        expect(find.text('Practice'), findsOneWidget);
        expect(find.byType(ExerciseHeader), findsOneWidget);
        expect(
          find.textContaining('Rep 7 of 10 — Homework unlocks at 10'),
          findsOneWidget,
        );
        expect(find.text('Rep 7 of 10'), findsOneWidget);
        expect(find.byType(ChoiceTile), findsNWidgets(4));
      });

      testWidgets('F-4: Idle with nothing selected disables Check', (t) async {
        var checks = 0;
        await _pump(
          t,
          size: size,
          feedback: const Idle(),
          onCheck: () => checks++,
        );
        expect(_button(t, 'Check').onPressed, isNull);
        await t.tap(find.text('Check'), warnIfMissed: false);
        expect(checks, 0);
      });

      testWidgets('F-4: Idle after selecting enables Check and fires it', (
        t,
      ) async {
        var checks = 0;
        await _pump(
          t,
          size: size,
          feedback: const Idle(),
          answer: const AnswerState(selected: 'B'),
          onCheck: () => checks++,
        );
        expect(_button(t, 'Check').onPressed, isNotNull);
        await t.tap(find.text('Check'));
        expect(checks, 1);
      });

      testWidgets('F-4: tapping a tile fires onSelect with its label', (
        t,
      ) async {
        final picks = <String>[];
        await _pump(
          t,
          size: size,
          feedback: const Idle(),
          onSelect: picks.add,
        );
        await t.tap(find.byKey(const ValueKey('choice-C')));
        expect(picks, ['C']);
      });

      testWidgets('F-4: Checking is loading, ignores taps, locks tiles', (
        t,
      ) async {
        var checks = 0;
        final picks = <String>[];
        await _pump(
          t,
          size: size,
          feedback: const Checking(),
          answer: const AnswerState(selected: 'B'),
          onCheck: () => checks++,
          onSelect: picks.add,
        );
        expect(_button(t, 'Check').isLoading, isTrue);
        await t.tap(find.byType(LoadingButton).last, warnIfMissed: false);
        expect(checks, 0);
        expect(_tile(t, 'A').onSelect, isNull);
        await t.tap(
          find.byKey(const ValueKey('choice-A')),
          warnIfMissed: false,
        );
        expect(picks, isEmpty);
      });

      testWidgets('F-4: FirstMiss marks the missed tile Incorrect', (t) async {
        await _pump(
          t,
          size: size,
          feedback: const FirstMiss(
            missed: 'A',
            noteMd: 'You added instead of subtracting.',
            hintMd: 'Subtract 3 first.',
          ),
          answer: const AnswerState(selected: 'A'),
          onCheck: () {},
        );
        expect(_tile(t, 'A').state, ChoiceTileState.incorrect);
        expect(_inTile('A', 'Incorrect'), findsOneWidget);
        expect(_tile(t, 'B').state, ChoiceTileState.idle);
      });

      testWidgets('F-4: FirstMiss shows the miss note and the hint panel', (
        t,
      ) async {
        await _pump(
          t,
          size: size,
          feedback: const FirstMiss(
            missed: 'A',
            noteMd: 'You added instead of subtracting.',
            hintMd: 'Subtract 3 first.',
          ),
          answer: const AnswerState(selected: 'A'),
          onCheck: () {},
        );
        final note = _note(t);
        expect(note.tone, MarginNoteTone.miss);
        expect(note.author, 'Mr. Samy');
        expect(note.bodyMd, 'You added instead of subtracting.');
        expect(find.byType(HintPanel), findsOneWidget);
        expect(
          t.widget<HintPanel>(find.byType(HintPanel)).md,
          'Subtract 3 first.',
        );
        expect(find.byType(WorkedExample), findsNothing);
      });

      testWidgets(
        'F-4: FirstMiss without noteMd uses the hint as the note body '
        'and hides the HintPanel',
        (t) async {
          await _pump(
            t,
            size: size,
            feedback: const FirstMiss(missed: 'A', hintMd: 'Subtract 3 first.'),
            answer: const AnswerState(selected: 'A'),
            onCheck: () {},
          );
          expect(_note(t).bodyMd, 'Subtract 3 first.');
          expect(find.byType(HintPanel), findsNothing);
        },
      );

      testWidgets('F-4: FirstMiss with no note and no hint shows neither', (
        t,
      ) async {
        await _pump(
          t,
          size: size,
          feedback: const FirstMiss(missed: 'A'),
          answer: const AnswerState(selected: 'A'),
          onCheck: () {},
        );
        expect(find.byType(MarginNote), findsNothing);
        expect(find.byType(HintPanel), findsNothing);
      });

      testWidgets('F-4: FirstMiss disables Check until another is picked', (
        t,
      ) async {
        await _pump(
          t,
          size: size,
          feedback: const FirstMiss(missed: 'A', noteMd: 'n'),
          answer: const AnswerState(selected: 'A'),
          onCheck: () {},
        );
        expect(_button(t, 'Check').onPressed, isNull);

        await _pump(
          t,
          size: size,
          feedback: const FirstMiss(missed: 'A', noteMd: 'n'),
          answer: const AnswerState(selected: 'B'),
          onCheck: () {},
        );
        expect(_button(t, 'Check').onPressed, isNotNull);
      });

      testWidgets(
        'F-4: "Pick another answer" shows only at 1280 while disabled',
        (t) async {
          await _pump(
            t,
            size: size,
            feedback: const FirstMiss(missed: 'A', noteMd: 'n'),
            answer: const AnswerState(selected: 'A'),
            onCheck: () {},
          );
          expect(
            find.text('Pick another answer'),
            size == _wide ? findsOneWidget : findsNothing,
          );
        },
      );

      testWidgets('F-4: Correct shows green note, worked example and Next', (
        t,
      ) async {
        var nexts = 0;
        await _pump(
          t,
          size: size,
          feedback: const Correct(
            noteMd: 'Nice work.',
            explanationMd: 'Subtract 3, then divide by 2.',
          ),
          answer: const AnswerState(selected: 'C'),
          onCheck: () {},
          onNext: () => nexts++,
        );
        expect(_note(t).tone, MarginNoteTone.correct);
        expect(_note(t).bodyMd, 'Nice work.');
        expect(find.byType(WorkedExample), findsOneWidget);
        expect(find.text('Check'), findsNothing);
        await t.tap(find.text('Next'));
        expect(nexts, 1);
      });

      testWidgets('F-4: Correct without noteMd shows a header-only note', (
        t,
      ) async {
        await _pump(
          t,
          size: size,
          feedback: const Correct(),
          answer: const AnswerState(selected: 'C'),
          onNext: () {},
        );
        expect(_note(t).tone, MarginNoteTone.correct);
        expect(_note(t).bodyMd, isEmpty);
        expect(find.byType(WorkedExample), findsNothing);
      });

      testWidgets('F-4: Revealed shows the three review labels', (t) async {
        await _pump(
          t,
          size: size,
          feedback: const Revealed(
            key: McqAnswerKey('C'),
            firstTry: 'A',
            noteMd: 'Watch the sign.',
            explanationMd: 'Subtract 3, then divide by 2.',
          ),
          answer: const AnswerState(selected: 'B'),
          onNext: () {},
        );
        expect(_inTile('C', 'Correct answer'), findsOneWidget);
        expect(_inTile('A', '1st try'), findsOneWidget);
        expect(_inTile('B', 'Your answer'), findsOneWidget);
        expect(_tile(t, 'D').state, ChoiceTileState.reviewOther);
      });

      testWidgets('F-4: Revealed shows miss note, worked example, Next', (
        t,
      ) async {
        var nexts = 0;
        await _pump(
          t,
          size: size,
          feedback: const Revealed(
            key: McqAnswerKey('C'),
            firstTry: 'A',
            noteMd: 'Watch the sign.',
            explanationMd: 'Subtract 3, then divide by 2.',
          ),
          answer: const AnswerState(selected: 'B'),
          onNext: () => nexts++,
        );
        expect(_note(t).tone, MarginNoteTone.miss);
        expect(_note(t).bodyMd, 'Watch the sign.');
        expect(find.byType(WorkedExample), findsOneWidget);
        await t.tap(find.text('Next'));
        expect(nexts, 1);
      });

      testWidgets('F-4: Revealed without noteMd renders no MarginNote', (
        t,
      ) async {
        await _pump(
          t,
          size: size,
          feedback: const Revealed(
            key: McqAnswerKey('C'),
            firstTry: 'A',
            explanationMd: 'Subtract 3, then divide by 2.',
          ),
          answer: const AnswerState(selected: 'B'),
          onNext: () {},
        );
        expect(find.byType(MarginNote), findsNothing);
        expect(find.byType(WorkedExample), findsOneWidget);
      });

      testWidgets('F-4: Back shows only when onPrev is given', (t) async {
        await _pump(t, size: size, feedback: const Idle());
        expect(find.text('Back'), findsNothing);

        var prevs = 0;
        await _pump(
          t,
          size: size,
          feedback: const Idle(),
          onPrev: () => prevs++,
        );
        await t.tap(find.text('Back'));
        expect(prevs, 1);
      });
    });
  }

  group('QuestionView margin note placement', () {
    const miss = FirstMiss(missed: 'A', noteMd: 'Check the sign.');

    for (final size in [_phone, _tablet]) {
      testWidgets('F-4: note is inline at ${size.width.toInt()}', (t) async {
        await _pump(
          t,
          size: size,
          feedback: miss,
          answer: const AnswerState(selected: 'A'),
        );
        expect(_note(t).inline, isTrue);
        expect(
          t.getTopLeft(find.byType(MarginNote)).dx,
          t.getTopLeft(find.byType(ExerciseHeader)).dx,
        );
        expect(
          t.getTopLeft(find.byType(MarginNote)).dy,
          greaterThan(
            t.getBottomLeft(find.byKey(const ValueKey('choice-D'))).dy,
          ),
        );
      });
    }

    testWidgets('F-4: note is an aside beside the column at 1280', (t) async {
      await _pump(
        t,
        size: _wide,
        feedback: miss,
        answer: const AnswerState(selected: 'A'),
      );
      expect(_note(t).inline, isFalse);
      final note = find.byType(MarginNote);
      expect(
        t.getTopLeft(note).dx,
        greaterThanOrEqualTo(
          t.getTopRight(find.byKey(const ValueKey('choice-A'))).dx,
        ),
      );
      expect(
        find.ancestor(of: note, matching: find.byType(Row)),
        findsWidgets,
      );
    });
  });

  group('QuestionView SPR', () {
    testWidgets('F-4: SPR FirstMiss gives SprInput no correctAnswer', (
      t,
    ) async {
      await _pump(
        t,
        size: _phone,
        question: _spr('q1'),
        feedback: const FirstMiss(missed: '5', noteMd: 'n'),
        answer: const AnswerState(sprText: '5'),
        onCheck: () {},
      );
      final input = t.widget<SprInput>(find.byType(SprInput));
      expect(input.correctAnswer, isNull);
      expect(input.state, SprInputState.editable);
    });

    testWidgets('F-4: SPR Revealed is incorrect with the key text', (t) async {
      await _pump(
        t,
        size: _phone,
        question: _spr('q1'),
        feedback: const Revealed(
          key: SprAnswerKey('3/4'),
          firstTry: '5',
          noteMd: 'n',
        ),
        answer: const AnswerState(sprText: '7'),
        onNext: () {},
      );
      final input = t.widget<SprInput>(find.byType(SprInput));
      expect(input.state, SprInputState.incorrect);
      expect(input.correctAnswer, '3/4');
    });

    testWidgets('F-4: SPR Correct is in the correct state', (t) async {
      await _pump(
        t,
        size: _phone,
        question: _spr('q1'),
        feedback: const Correct(),
        answer: const AnswerState(sprText: '3/4'),
        onNext: () {},
      );
      expect(
        t.widget<SprInput>(find.byType(SprInput)).state,
        SprInputState.correct,
      );
    });

    testWidgets('F-4: SPR Checking is disabled', (t) async {
      await _pump(
        t,
        size: _phone,
        question: _spr('q1'),
        feedback: const Checking(),
        answer: const AnswerState(sprText: '3/4'),
        onCheck: () {},
      );
      expect(
        t.widget<SprInput>(find.byType(SprInput)).state,
        SprInputState.disabled,
      );
    });

    testWidgets('F-4: phone SPR uses the keypad', (t) async {
      await _pump(
        t,
        size: _phone,
        question: _spr('q1'),
        feedback: const Idle(),
      );
      expect(t.widget<SprInput>(find.byType(SprInput)).useKeypad, isTrue);
    });

    testWidgets('F-4: changing the question id resets the keypad hint', (
      t,
    ) async {
      const hint = 'A fraction has only one slash.';
      await _setSize(t, _phone);
      var question = _spr('q1');
      var text = '';
      late StateSetter rebuild;
      await t.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return _app(
              QuestionView(
                title: 'Linear equations',
                question: question,
                mode: _mode(const Idle()),
                answer: AnswerState(sprText: text),
                onSprChanged: (v) => setState(() => text = v),
              ),
            );
          },
        ),
      );
      await t.pump();

      await t.tap(find.text('3'));
      await t.pump();
      await t.tap(find.text('/'));
      await t.pump();
      await t.tap(find.text('/'));
      await t.pump();
      expect(find.text(hint), findsOneWidget);

      rebuild(() {
        question = _spr('q2');
        text = '';
      });
      await t.pump();
      await t.pump();
      expect(find.text(hint), findsNothing);
    });
  });

  group('QuestionView figures and overflow', () {
    testWidgets('F-4: figureBuilder is called once per image path', (
      t,
    ) async {
      final calls = <String>[];
      await _pump(
        t,
        size: _phone,
        question: _mcq(imagePaths: const ['a.png', 'b.png']),
        feedback: const Idle(),
        figureBuilder: (context, path) {
          calls.add(path);
          return SizedBox(key: ValueKey('fig-$path'), height: 40);
        },
      );
      expect(calls.toSet(), {'a.png', 'b.png'});
      expect(find.byKey(const ValueKey('fig-a.png')), findsOneWidget);
      expect(find.byKey(const ValueKey('fig-b.png')), findsOneWidget);
    });

    testWidgets('F-4: null figureBuilder renders no figures', (t) async {
      await _pump(
        t,
        size: _phone,
        question: _mcq(imagePaths: const ['a.png']),
        feedback: const Idle(),
      );
      expect(t.takeException(), isNull);
      expect(find.byType(ChoiceTile), findsNWidgets(4));
    });

    testWidgets(
      'F-4: long Arabic stem, note and hint at 360 / 2x text do not '
      'overflow and the footer stays visible',
      (t) async {
        t.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
        final arabic = List.filled(
          40,
          'احسب قيمة س في المعادلة الخطية التالية بعناية',
        ).join(' ');
        await _pump(
          t,
          size: _phone,
          question: QuestionData(
            id: 'q1',
            label: '4.2 · Ex 7',
            stemMd: arabic,
            kind: const McqKind(_choices),
          ),
          feedback: FirstMiss(missed: 'A', noteMd: arabic, hintMd: arabic),
          answer: const AnswerState(selected: 'B'),
          onCheck: () {},
          onPrev: () {},
        );
        expect(t.takeException(), isNull);
        final check = find.byWidgetPredicate(
          (w) => w is LoadingButton && w.label == 'Check',
        );
        expect(check, findsOneWidget);
        final rect = t.getRect(check);
        expect(rect.bottom, lessThanOrEqualTo(_phone.height));
        expect(rect.top, greaterThanOrEqualTo(0));
      },
    );
  });
}
