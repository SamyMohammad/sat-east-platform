import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/theme/app_theme.dart';
import 'package:sat_east_client/shared/widgets/booklet_dialog.dart';
import 'package:sat_east_client/shared/widgets/loading_button.dart';
import 'package:sat_east_client/shared/widgets/question_view/answer_state.dart';
import 'package:sat_east_client/shared/widgets/question_view/parts/exam_bar.dart';
import 'package:sat_east_client/shared/widgets/question_view/parts/exercise_header.dart';
import 'package:sat_east_client/shared/widgets/question_view/parts/hint_panel.dart';
import 'package:sat_east_client/shared/widgets/question_view/parts/margin_note.dart';
import 'package:sat_east_client/shared/widgets/question_view/parts/question_navigator.dart';
import 'package:sat_east_client/shared/widgets/question_view/parts/quiz_question_header.dart';
import 'package:sat_east_client/shared/widgets/question_view/parts/worked_example.dart';
import 'package:sat_east_client/shared/widgets/question_view/question_data.dart';
import 'package:sat_east_client/shared/widgets/question_view/question_view.dart';
import 'package:sat_east_client/shared/widgets/question_view/question_view_mode.dart';
import 'package:sat_east_client/shared/widgets/spr_input.dart';

const _phone = Size(360, 800);
const _wide = Size(1280, 800);

const _total = 12;
const _fullTitle = 'Quiz · 4.2 Linear equations';
const _warnAt = Duration(minutes: 5);

const _mcq = QuestionData(
  id: 'q4',
  label: '4.2 · Ex 4',
  stemMd: r'Solve $2x + 3 = 7$.',
  kind: McqKind([
    ChoiceData(label: 'A', md: r'$x = 1$'),
    ChoiceData(label: 'B', md: r'$x = 2$'),
    ChoiceData(label: 'C', md: r'$x = 3$'),
    ChoiceData(label: 'D', md: r'$x = 4$'),
  ]),
);

const _spr = QuestionData(
  id: 'q4s',
  label: '4.2 · Ex 4',
  stemMd: r'Solve $4x = 3$.',
  kind: SprKind(),
);

QuizMode _mode({
  int index = 3,
  Duration remaining = const Duration(minutes: 14, seconds: 30),
  bool timerHidden = false,
  Set<int> answered = const {0, 1, 3},
  Set<int> marked = const {2},
}) => QuizMode(
  title: 'Quiz 4.2',
  index: index,
  total: _total,
  remaining: remaining,
  timeBudget: const Duration(minutes: 18),
  warnAt: _warnAt,
  timerHidden: timerHidden,
  answered: answered,
  marked: marked,
);

class _Calls {
  final jumps = <int>[];
  final selects = <String>[];
  final eliminates = <String>[];
  int marks = 0;
  int submits = 0;
  int nexts = 0;
  int prevs = 0;
  int toggles = 0;
}

void _setSize(WidgetTester t, Size size) {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
}

Widget _app(Widget child) => MaterialApp(
  theme: AppTheme.light(),
  home: Scaffold(body: child),
);

Future<_Calls> _pump(
  WidgetTester t, {
  required Size size,
  QuizMode? mode,
  QuestionData question = _mcq,
  AnswerState answer = const AnswerState(),
}) async {
  _setSize(t, size);
  final calls = _Calls();
  await t.pumpWidget(
    _app(
      QuestionView(
        title: _fullTitle,
        question: question,
        mode: mode ?? _mode(),
        answer: answer,
        onSelect: calls.selects.add,
        onEliminate: calls.eliminates.add,
        onMark: () => calls.marks++,
        onJumpTo: calls.jumps.add,
        onSubmit: () => calls.submits++,
        onNext: () => calls.nexts++,
        onPrev: () => calls.prevs++,
        onToggleTimer: () => calls.toggles++,
      ),
    ),
  );
  await t.pumpAndSettle();
  return calls;
}

LoadingButton _button(WidgetTester t, String label) => t.widget<LoadingButton>(
  find.byWidgetPredicate((w) => w is LoadingButton && w.label == label),
);

Finder _cell(int i) => find.byKey(ValueKey('nav-cell-$i'));
final Finder _grid = find.byType(QuestionNavigatorGrid);
final Finder _dialog = find.byType(BookletDialog);
Finder _inDialog(Finder f) => find.descendant(of: _dialog, matching: f);
final Finder _markToggle = find.descendant(
  of: find.byType(QuizQuestionHeader),
  matching: find.byType(OutlinedButton),
);

Future<void> _key(WidgetTester t, LogicalKeyboardKey key) async {
  await t.sendKeyEvent(key);
  await t.pump();
}

Future<void> _shiftKey(WidgetTester t, LogicalKeyboardKey key) async {
  await t.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  await t.sendKeyEvent(key);
  await t.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  await t.pump();
}

void main() {
  for (final size in [_phone, _wide]) {
    final w = size.width.toInt();
    final compact = size == _phone;
    const navLabel = 'Question 4 of $_total';

    group('QuestionView quiz at $w', () {
      testWidgets('F-4: chrome shows exam bar and quiz header, no exercise '
          'header', (t) async {
        await _pump(t, size: size);

        expect(find.byType(ExamBar), findsOneWidget);
        expect(find.text('14:30'), findsOneWidget);
        if (compact) {
          expect(find.text('Quiz 4.2'), findsOneWidget);
          expect(find.text('12 questions'), findsOneWidget);
          expect(find.text(_fullTitle), findsNothing);
          expect(find.text('Hide'), findsNothing);
        } else {
          expect(find.text(_fullTitle), findsOneWidget);
          expect(find.text('Hide'), findsOneWidget);
        }
        expect(find.byType(ExerciseHeader), findsNothing);
        expect(find.byType(QuizQuestionHeader), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(QuizQuestionHeader),
            matching: find.text('4'),
          ),
          findsOneWidget,
        );
      });

      testWidgets('F-4: Hide fires onToggleTimer only on the wide bar', (
        t,
      ) async {
        final calls = await _pump(t, size: size);
        if (compact) {
          expect(find.text('Hide'), findsNothing);
          return;
        }
        await t.tap(find.text('Hide'));
        expect(calls.toggles, 1);
      });

      testWidgets('F-4: tapping the mark toggle fires onMark', (t) async {
        final calls = await _pump(t, size: size);
        expect(find.text('Mark for review'), findsOneWidget);
        await t.tap(find.text('Mark for review'));
        expect(calls.marks, 1);
      });

      testWidgets('F-4: pressing M fires onMark', (t) async {
        final calls = await _pump(t, size: size);
        await _key(t, LogicalKeyboardKey.keyM);
        expect(calls.marks, 1);
      });

      testWidgets('F-4: a marked answer shows "Marked for review"', (t) async {
        await _pump(
          t,
          size: size,
          answer: const AnswerState(marked: true),
        );
        expect(find.text('Marked for review'), findsOneWidget);
        expect(find.text('Mark for review'), findsNothing);
        expect(find.byIcon(Icons.bookmark), findsOneWidget);
      });

      testWidgets('F-4: footer button opens the right navigator and cells '
          'jump', (t) async {
        final calls = await _pump(t, size: size);
        expect(find.text(navLabel), findsOneWidget);
        expect(find.byIcon(Icons.expand_less), findsOneWidget);

        await t.tap(find.text(navLabel));
        await t.pumpAndSettle();

        expect(find.text('Quiz 4.2 questions'), findsOneWidget);
        expect(_grid, findsOneWidget);
        expect(
          find.byTooltip(compact ? 'Close sheet' : 'Close navigator'),
          findsOneWidget,
        );

        await t.tap(_cell(9));
        await t.pumpAndSettle();

        expect(calls.jumps, [9]);
        expect(_grid, findsNothing);
      });

      testWidgets('F-4: navigator cells reflect answered, marked, current', (
        t,
      ) async {
        final handle = t.ensureSemantics();
        await _pump(t, size: size);
        await t.tap(find.text(navLabel));
        await t.pumpAndSettle();

        expect(find.bySemanticsLabel('Question 1, answered'), findsOneWidget);
        expect(find.bySemanticsLabel('Question 2, answered'), findsOneWidget);
        expect(
          find.bySemanticsLabel('Question 3, unanswered, marked'),
          findsOneWidget,
        );
        expect(
          find.bySemanticsLabel('Question 4, answered, current'),
          findsOneWidget,
        );
        expect(find.bySemanticsLabel('Question 5, unanswered'), findsOneWidget);
        handle.dispose();
      });

      testWidgets('F-4: navigator Submit quiz opens the confirm dialog and '
          'confirming fires onSubmit once', (t) async {
        final calls = await _pump(t, size: size);
        await t.tap(find.text(navLabel));
        await t.pumpAndSettle();

        await t.tap(find.text('Submit quiz'));
        await t.pumpAndSettle();

        expect(_grid, findsNothing);
        expect(t.widget<BookletDialog>(_dialog).title, 'Submit quiz?');
        expect(
          _inDialog(
            find.text('After you submit, your answers are locked and marked.'),
          ),
          findsOneWidget,
        );
        expect(calls.submits, 0);

        await t.tap(_inDialog(find.text('Submit quiz')));
        await t.pumpAndSettle();

        expect(calls.submits, 1);
        expect(_dialog, findsNothing);
      });

      testWidgets('F-4: last question primary reads Submit quiz, not Next', (
        t,
      ) async {
        final calls = await _pump(t, size: size, mode: _mode(index: 11));
        expect(find.text('Next'), findsNothing);
        expect(_button(t, 'Submit quiz').onPressed, isNotNull);

        await t.tap(find.text('Submit quiz'));
        await t.pumpAndSettle();
        expect(t.widget<BookletDialog>(_dialog).title, 'Submit quiz?');
        expect(calls.submits, 0);

        await t.tap(_inDialog(find.text('Submit quiz')));
        await t.pumpAndSettle();
        expect(calls.submits, 1);
        expect(calls.nexts, 0);
      });

      testWidgets('F-4: Back and Next fire mid-way', (t) async {
        final calls = await _pump(t, size: size);
        expect(find.text('Submit quiz'), findsNothing);
        await t.tap(find.text('Back'));
        await t.tap(find.text('Next'));
        expect(calls.prevs, 1);
        expect(calls.nexts, 1);
      });

      testWidgets('F-4: Back is disabled on the first question', (t) async {
        final calls = await _pump(t, size: size, mode: _mode(index: 0));
        expect(_button(t, 'Back').onPressed, isNull);
        await _key(t, LogicalKeyboardKey.arrowLeft);
        expect(calls.prevs, 0);
      });

      testWidgets('F-4: right arrow on the last question fires nothing', (
        t,
      ) async {
        final calls = await _pump(t, size: size, mode: _mode(index: 11));
        await _key(t, LogicalKeyboardKey.arrowRight);
        expect(calls.nexts, 0);
        expect(calls.submits, 0);
      });

      testWidgets('F-4: arrows and choice keys work before time is up', (
        t,
      ) async {
        final calls = await _pump(t, size: size);
        await _key(t, LogicalKeyboardKey.arrowRight);
        await _key(t, LogicalKeyboardKey.arrowLeft);
        await _key(t, LogicalKeyboardKey.keyA);
        await _shiftKey(t, LogicalKeyboardKey.keyB);
        expect(calls.nexts, 1);
        expect(calls.prevs, 1);
        expect(calls.selects, ['A']);
        expect(calls.eliminates, ['B']);
      });

      testWidgets('F-4: warning banner shows at 4:41 with warnAt 5:00', (
        t,
      ) async {
        await _pump(
          t,
          size: size,
          mode: _mode(remaining: const Duration(minutes: 4, seconds: 41)),
        );
        expect(find.byType(ExamWarningBanner), findsOneWidget);
        expect(find.textContaining('5 minutes left.'), findsOneWidget);
        expect(find.text('04:41'), findsOneWidget);
      });

      testWidgets('F-4: no warning banner at 5:01', (t) async {
        await _pump(
          t,
          size: size,
          mode: _mode(remaining: const Duration(minutes: 5, seconds: 1)),
        );
        expect(find.byType(ExamWarningBanner), findsNothing);
      });

      testWidgets('F-4: Review marked opens the navigator when marked is not '
          'empty', (t) async {
        await _pump(
          t,
          size: size,
          mode: _mode(remaining: const Duration(minutes: 4, seconds: 41)),
        );
        await t.tap(find.text('Review marked'));
        await t.pumpAndSettle();
        expect(_grid, findsOneWidget);
      });

      testWidgets('F-4: Review marked is absent when nothing is marked', (
        t,
      ) async {
        await _pump(
          t,
          size: size,
          mode: _mode(
            remaining: const Duration(minutes: 4, seconds: 41),
            marked: const {},
          ),
        );
        expect(find.byType(ExamWarningBanner), findsOneWidget);
        expect(find.text('Review marked'), findsNothing);
      });

      testWidgets('F-4: quiz never shows feedback widgets', (t) async {
        await _pump(t, size: size);
        expect(find.byType(MarginNote), findsNothing);
        expect(find.byType(HintPanel), findsNothing);
        expect(find.byType(WorkedExample), findsNothing);
      });

      testWidgets('F-4: SPR input is editable before time is up', (t) async {
        await _pump(t, size: size, question: _spr);
        expect(
          t.widget<SprInput>(find.byType(SprInput)).state,
          SprInputState.editable,
        );
      });
    });

    group('QuestionView quiz time-up at $w', () {
      const timeUp = Duration.zero;

      testWidgets('F-4: tapping choice tiles fires nothing', (t) async {
        final calls = await _pump(
          t,
          size: size,
          mode: _mode(remaining: timeUp),
        );
        await t.tap(find.byKey(const ValueKey('choice-A')));
        await t.tap(find.byKey(const ValueKey('choice-B')));
        await t.pump();
        expect(calls.selects, isEmpty);
        expect(calls.eliminates, isEmpty);
      });

      testWidgets('F-4: A, Shift+B, M and arrows fire nothing', (t) async {
        final calls = await _pump(
          t,
          size: size,
          mode: _mode(remaining: timeUp),
        );
        await _key(t, LogicalKeyboardKey.keyA);
        await _shiftKey(t, LogicalKeyboardKey.keyB);
        await _key(t, LogicalKeyboardKey.keyM);
        await _key(t, LogicalKeyboardKey.arrowLeft);
        await _key(t, LogicalKeyboardKey.arrowRight);

        expect(calls.selects, isEmpty);
        expect(calls.eliminates, isEmpty);
        expect(calls.marks, 0);
        expect(calls.prevs, 0);
        expect(calls.nexts, 0);
      });

      testWidgets('F-4: Back, Next and the mark toggle are disabled', (
        t,
      ) async {
        final calls = await _pump(
          t,
          size: size,
          mode: _mode(remaining: timeUp),
        );
        expect(_button(t, 'Back').onPressed, isNull);
        expect(_button(t, 'Next').onPressed, isNull);
        expect(t.widget<OutlinedButton>(_markToggle).onPressed, isNull);

        await t.tap(_markToggle, warnIfMissed: false);
        expect(calls.marks, 0);
        expect(calls.prevs, 0);
        expect(calls.nexts, 0);
      });

      testWidgets('F-4: Submit quiz is disabled on the last question', (
        t,
      ) async {
        final calls = await _pump(
          t,
          size: size,
          mode: _mode(index: 11, remaining: timeUp),
        );
        expect(_button(t, 'Submit quiz').onPressed, isNull);
        await t.tap(find.text('Submit quiz'), warnIfMissed: false);
        await t.pumpAndSettle();
        expect(_dialog, findsNothing);
        expect(calls.submits, 0);
      });

      testWidgets('F-4: navigator cells do not jump', (t) async {
        final calls = await _pump(
          t,
          size: size,
          mode: _mode(remaining: timeUp),
        );
        await t.tap(find.text('Question 4 of $_total'));
        await t.pumpAndSettle();
        if (_grid.evaluate().isNotEmpty) {
          await t.tap(_cell(9), warnIfMissed: false);
          await t.pumpAndSettle();
        }
        expect(calls.jumps, isEmpty);
      });

      testWidgets('F-4: SPR input is disabled', (t) async {
        await _pump(
          t,
          size: size,
          question: _spr,
          mode: _mode(remaining: timeUp),
        );
        expect(
          t.widget<SprInput>(find.byType(SprInput)).state,
          SprInputState.disabled,
        );
      });
    });
  }

  group('QuestionView quiz wide bar', () {
    testWidgets('F-4: hidden timer shows "Timer hidden" and Show', (t) async {
      await _pump(t, size: _wide, mode: _mode(timerHidden: true));
      expect(find.text('Timer hidden'), findsOneWidget);
      expect(find.text('Show'), findsOneWidget);
      expect(find.text('14:30'), findsNothing);
    });
  });

  group('QuestionView quiz width changes', () {
    testWidgets('F-4: resizing 1280 to 360 swaps the popover button for the '
        'sheet button and callbacks still fire', (t) async {
      final calls = await _pump(t, size: _wide);

      await t.tap(find.text('Question 4 of $_total'));
      await t.pumpAndSettle();
      expect(find.byTooltip('Close navigator'), findsOneWidget);
      await t.tap(_cell(2));
      await t.pumpAndSettle();
      expect(calls.jumps, [2]);

      t.view.physicalSize = _phone;
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(find.text('Hide'), findsNothing);

      await t.tap(find.text('Question 4 of $_total'));
      await t.pumpAndSettle();
      expect(find.byTooltip('Close sheet'), findsOneWidget);
      expect(find.byTooltip('Close navigator'), findsNothing);
      await t.tap(_cell(7));
      await t.pumpAndSettle();
      expect(calls.jumps, [2, 7]);

      await t.tap(find.text('Next'));
      await t.tap(find.text('Mark for review'));
      expect(calls.nexts, 1);
      expect(calls.marks, 1);
    });
  });
}
