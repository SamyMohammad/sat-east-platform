import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:sat_east_client/core/theme/app_theme.dart';
import 'package:sat_east_client/shared/widgets/question_view/answer_state.dart';
import 'package:sat_east_client/shared/widgets/question_view/parts/question_shortcuts.dart';
import 'package:sat_east_client/shared/widgets/question_view/practice_feedback.dart';
import 'package:sat_east_client/shared/widgets/question_view/question_data.dart';
import 'package:sat_east_client/shared/widgets/question_view/question_view.dart';
import 'package:sat_east_client/shared/widgets/question_view/question_view_mode.dart';

const _wide = Size(1280, 800);

const _choices = [
  ChoiceData(label: 'A', md: r'$x = 1$'),
  ChoiceData(label: 'B', md: r'$x = 2$'),
  ChoiceData(label: 'C', md: r'$x = 3$'),
  ChoiceData(label: 'D', md: r'$x = 4$'),
];

const _mcq = QuestionData(
  id: 'q1',
  label: '4.2 · Ex 7',
  stemMd: r'Solve $2x + 3 = 7$.',
  kind: McqKind(_choices),
);

const _mcq3 = QuestionData(
  id: 'q3',
  label: '4.2 · Ex 8',
  stemMd: r'Solve $x = 1$.',
  kind: McqKind([
    ChoiceData(label: 'A', md: r'$x = 1$'),
    ChoiceData(label: 'B', md: r'$x = 2$'),
    ChoiceData(label: 'C', md: r'$x = 3$'),
  ]),
);

const _spr = QuestionData(
  id: 'q2',
  label: '4.2 · Ex 7',
  stemMd: r'Solve $4x = 3$.',
  kind: SprKind(),
);

class _Calls {
  final selects = <String>[];
  final eliminates = <String>[];
  int marks = 0;
  int prevs = 0;
  int nexts = 0;
}

const _practiceIdle = PracticeMode(
  feedback: Idle(),
  rep: 7,
  repTarget: 10,
);

const _homework = HomeworkMode(
  title: 'Homework 4.2',
  index: 5,
  total: 20,
  saveStatus: SaveStatus.saved,
);

HomeworkMode _homeworkAt(int index) => HomeworkMode(
  title: 'Homework 4.2',
  index: index,
  total: 20,
  saveStatus: SaveStatus.saved,
);

Widget _app(Widget child) => MaterialApp(
  theme: AppTheme.light(),
  home: Scaffold(body: child),
);

Future<_Calls> _pump(
  WidgetTester t, {
  QuestionViewMode mode = _practiceIdle,
  QuestionData question = _mcq,
  bool withMark = false,
  bool withNav = true,
}) async {
  t.view.physicalSize = _wide;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final calls = _Calls();
  await t.pumpWidget(
    _app(
      QuestionView(
        title: 'Linear equations',
        question: question,
        mode: mode,
        answer: const AnswerState(),
        onSelect: calls.selects.add,
        onEliminate: calls.eliminates.add,
        onMark: withMark ? () => calls.marks++ : null,
        onPrev: withNav ? () => calls.prevs++ : null,
        onNext: withNav ? () => calls.nexts++ : null,
      ),
    ),
  );
  await t.pump();
  return calls;
}

Future<void> _shiftKey(WidgetTester t, LogicalKeyboardKey key) async {
  await t.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  await t.sendKeyEvent(key);
  await t.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
}

void main() {
  group('QuestionView shortcuts in practice Idle', () {
    testWidgets('F-4: A selects A without clicking into the view', (t) async {
      final calls = await _pump(t);
      await t.sendKeyEvent(LogicalKeyboardKey.keyA);
      expect(calls.selects, ['A']);
    });

    testWidgets('F-4: B selects B', (t) async {
      final calls = await _pump(t);
      await t.sendKeyEvent(LogicalKeyboardKey.keyB);
      expect(calls.selects, ['B']);
    });

    testWidgets('F-4: Shift+C eliminates C and does not select', (t) async {
      final calls = await _pump(t);
      await _shiftKey(t, LogicalKeyboardKey.keyC);
      expect(calls.eliminates, ['C']);
      expect(calls.selects, isEmpty);
    });

    testWidgets('F-4: right arrow does not fire onNext under Idle', (t) async {
      final calls = await _pump(t);
      await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      expect(calls.nexts, 0);
      expect(calls.prevs, 0);
    });

    testWidgets('F-4: right arrow fires onNext under Correct', (t) async {
      final calls = await _pump(
        t,
        mode: const PracticeMode(
          feedback: Correct(),
          rep: 7,
          repTarget: 10,
        ),
      );
      await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      expect(calls.nexts, 1);
    });

    testWidgets('F-4: right arrow fires onNext under Revealed', (t) async {
      final calls = await _pump(
        t,
        mode: const PracticeMode(
          feedback: Revealed(key: McqAnswerKey('B'), firstTry: 'A'),
          rep: 7,
          repTarget: 10,
        ),
      );
      await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      expect(calls.nexts, 1);
    });

    testWidgets('F-4: left arrow fires onPrev', (t) async {
      final calls = await _pump(t);
      await t.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      expect(calls.prevs, 1);
      expect(calls.nexts, 0);
    });

    testWidgets('F-4: arrows do nothing when onNext and onPrev are null', (
      t,
    ) async {
      final calls = await _pump(t, withNav: false);
      await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await t.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      expect(calls.nexts, 0);
      expect(calls.prevs, 0);
      expect(t.takeException(), isNull);
    });
  });

  group('QuestionView shortcuts in homework', () {
    testWidgets('F-4: M fires onMark when it is non-null', (t) async {
      final calls = await _pump(t, mode: _homework, withMark: true);
      await t.sendKeyEvent(LogicalKeyboardKey.keyM);
      expect(calls.marks, 1);
    });

    testWidgets('F-4: M does nothing when onMark is null', (t) async {
      final calls = await _pump(t, mode: _homework);
      await t.sendKeyEvent(LogicalKeyboardKey.keyM);
      expect(calls.marks, 0);
      expect(t.takeException(), isNull);
    });

    testWidgets('F-4: arrows fire onPrev and onNext mid-index', (t) async {
      final calls = await _pump(t, mode: _homework);
      await t.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      expect(calls.prevs, 1);
      expect(calls.nexts, 1);
    });

    testWidgets('F-4: left arrow does nothing at index 0', (t) async {
      final calls = await _pump(t, mode: _homeworkAt(0));
      await t.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      expect(calls.prevs, 0);
    });

    testWidgets('F-4: right arrow does nothing at the last index', (t) async {
      final calls = await _pump(t, mode: _homeworkAt(19));
      await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      expect(calls.nexts, 0);
    });

    testWidgets('F-4: A selects in homework', (t) async {
      final calls = await _pump(t, mode: _homework);
      await t.sendKeyEvent(LogicalKeyboardKey.keyA);
      expect(calls.selects, ['A']);
    });
  });

  group('QuestionView shortcuts while typing in SPR (Review Focus 1)', () {
    testWidgets('F-4: typing a and pressing left fires no callback', (
      t,
    ) async {
      final calls = await _pump(t, question: _spr, withMark: true);
      await t.tap(find.byType(TextField));
      await t.pump();

      await t.sendKeyEvent(LogicalKeyboardKey.keyA);
      await t.sendKeyEvent(LogicalKeyboardKey.arrowLeft);

      expect(calls.selects, isEmpty);
      expect(calls.prevs, 0);
      expect(calls.nexts, 0);
    });

    testWidgets('F-4: right arrow and M inside the SPR field fire nothing', (
      t,
    ) async {
      final calls = await _pump(t, question: _spr, withMark: true);
      await t.tap(find.byType(TextField));
      await t.pump();

      await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await t.sendKeyEvent(LogicalKeyboardKey.keyM);

      expect(calls.nexts, 0);
      expect(calls.marks, 0);
    });
  });

  group('QuestionView shortcuts caret in SPR field (final review I1)', () {
    Future<(_Calls, TextEditingController)> pumpSpr(WidgetTester t) async {
      t.view.physicalSize = _wide;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final calls = _Calls();
      await t.pumpWidget(
        _app(
          QuestionView(
            title: 'Linear equations',
            question: _spr,
            mode: _homework,
            answer: const AnswerState(sprText: '123'),
            onSelect: calls.selects.add,
            onEliminate: calls.eliminates.add,
            onPrev: () => calls.prevs++,
            onNext: () => calls.nexts++,
          ),
        ),
      );
      await t.pump();
      return (calls, t.widget<TextField>(find.byType(TextField)).controller!);
    }

    testWidgets('F-4: left arrow in the SPR field moves the caret only', (
      t,
    ) async {
      final (calls, controller) = await pumpSpr(t);
      await t.tap(find.byType(TextField));
      await t.pump();
      controller.selection = const TextSelection.collapsed(offset: 3);
      await t.pump();

      await t.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await t.pump();

      expect(controller.selection.baseOffset, 2);
      expect(calls.prevs, 0);
      expect(calls.nexts, 0);
    });

    testWidgets('F-4: left arrow fires onPrev once focus is out of the field', (
      t,
    ) async {
      final (calls, _) = await pumpSpr(t);

      await t.sendKeyEvent(LogicalKeyboardKey.arrowLeft);

      expect(calls.prevs, 1);
    });
  });

  group('QuestionView shortcuts when locked (Review Focus 2)', () {
    testWidgets('F-4: A does not select under Checking', (t) async {
      final calls = await _pump(
        t,
        mode: const PracticeMode(
          feedback: Checking(),
          rep: 7,
          repTarget: 10,
        ),
      );
      await t.sendKeyEvent(LogicalKeyboardKey.keyA);
      await _shiftKey(t, LogicalKeyboardKey.keyB);
      expect(calls.selects, isEmpty);
      expect(calls.eliminates, isEmpty);
    });

    testWidgets('F-4: A does not select under Revealed', (t) async {
      final calls = await _pump(
        t,
        mode: const PracticeMode(
          feedback: Revealed(key: McqAnswerKey('B'), firstTry: 'A'),
          rep: 7,
          repTarget: 10,
        ),
      );
      await t.sendKeyEvent(LogicalKeyboardKey.keyA);
      await _shiftKey(t, LogicalKeyboardKey.keyB);
      expect(calls.selects, isEmpty);
      expect(calls.eliminates, isEmpty);
    });

    testWidgets('F-4: D does nothing on a 3-choice question', (t) async {
      final calls = await _pump(t, question: _mcq3);
      await t.sendKeyEvent(LogicalKeyboardKey.keyD);
      await _shiftKey(t, LogicalKeyboardKey.keyD);
      expect(calls.selects, isEmpty);
      expect(calls.eliminates, isEmpty);
      expect(t.takeException(), isNull);
    });
  });

  group('QuestionShortcuts', () {
    testWidgets(
      'F-4: with choicesInteractive false A does nothing but M fires onMark',
      (t) async {
        final selects = <String>[];
        final eliminates = <String>[];
        var marks = 0;
        await t.pumpWidget(
          _app(
            QuestionShortcuts(
              labels: const ['A', 'B', 'C', 'D'],
              choicesInteractive: false,
              onSelect: selects.add,
              onEliminate: eliminates.add,
              onMark: () => marks++,
              child: const SizedBox.expand(),
            ),
          ),
        );
        await t.pump();

        await t.sendKeyEvent(LogicalKeyboardKey.keyA);
        await _shiftKey(t, LogicalKeyboardKey.keyB);
        await t.sendKeyEvent(LogicalKeyboardKey.keyM);

        expect(selects, isEmpty);
        expect(eliminates, isEmpty);
        expect(marks, 1);
      },
    );
  });
}
