import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/theme/app_theme.dart';
import 'package:sat_east_client/shared/widgets/booklet_dialog.dart';
import 'package:sat_east_client/shared/widgets/loading_button.dart';
import 'package:sat_east_client/shared/widgets/question_view/answer_state.dart';
import 'package:sat_east_client/shared/widgets/question_view/parts/exercise_header.dart';
import 'package:sat_east_client/shared/widgets/question_view/parts/hint_panel.dart';
import 'package:sat_east_client/shared/widgets/question_view/parts/homework_navigator.dart';
import 'package:sat_east_client/shared/widgets/question_view/parts/margin_note.dart';
import 'package:sat_east_client/shared/widgets/question_view/parts/question_header.dart';
import 'package:sat_east_client/shared/widgets/question_view/parts/question_navigator.dart';
import 'package:sat_east_client/shared/widgets/question_view/parts/worked_example.dart';
import 'package:sat_east_client/shared/widgets/question_view/question_data.dart';
import 'package:sat_east_client/shared/widgets/question_view/question_view.dart';
import 'package:sat_east_client/shared/widgets/question_view/question_view_mode.dart';

const _phone = Size(360, 800);
const _tablet = Size(768, 1024);
const _wide = Size(1280, 800);

const _total = 20;

/// 15 answered; unanswered are 8, 13, 17, 18, 19 (5 of them).
const _answered = {0, 1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 14, 15, 16};
const _unansweredChips = ['Q9', 'Q14', 'Q18', 'Q19', 'Q20'];

const _question = QuestionData(
  id: 'q6',
  label: '4.2 · Ex 6',
  stemMd: r'Solve $2x + 3 = 7$.',
  kind: McqKind([
    ChoiceData(label: 'A', md: r'$x = 1$'),
    ChoiceData(label: 'B', md: r'$x = 2$'),
    ChoiceData(label: 'C', md: r'$x = 3$'),
    ChoiceData(label: 'D', md: r'$x = 4$'),
  ]),
);

HomeworkMode _mode({
  int index = 5,
  SaveStatus status = SaveStatus.saved,
  Set<int> answered = _answered,
  Set<int> marked = const {2, 8},
}) => HomeworkMode(
  title: 'Homework 4.2',
  index: index,
  total: _total,
  saveStatus: status,
  answered: answered,
  marked: marked,
);

class _Calls {
  final jumps = <int>[];
  int submits = 0;
  int retries = 0;
  int nexts = 0;
  int prevs = 0;
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

QuestionView _view(_Calls calls, HomeworkMode mode) => QuestionView(
  title: 'Homework 4.2',
  question: _question,
  mode: mode,
  answer: const AnswerState(),
  onJumpTo: calls.jumps.add,
  onSubmit: () => calls.submits++,
  onRetrySave: () => calls.retries++,
  onNext: () => calls.nexts++,
  onPrev: () => calls.prevs++,
);

Future<_Calls> _pump(
  WidgetTester t, {
  required Size size,
  HomeworkMode? mode,
}) async {
  _setSize(t, size);
  final calls = _Calls();
  await t.pumpWidget(_app(_view(calls, mode ?? _mode())));
  await t.pumpAndSettle();
  return calls;
}

LoadingButton _button(WidgetTester t, String label) => t.widget<LoadingButton>(
  find.byWidgetPredicate((w) => w is LoadingButton && w.label == label),
);

final Finder _panel = find.byKey(const ValueKey('homework-navigator-panel'));
Finder _cell(int i) => find.byKey(ValueKey('nav-cell-$i'));
Finder _inPanel(Finder f) => find.descendant(of: _panel, matching: f);
final Finder _dialog = find.byType(BookletDialog);
Finder _inDialog(Finder f) => find.descendant(of: _dialog, matching: f);

Future<void> _openSubmitDialog(WidgetTester t) async {
  await t.tap(_inPanel(find.text('Submit homework')));
  await t.pumpAndSettle();
}

void main() {
  group('QuestionNavigatorGrid semantics', () {
    testWidgets('F-4: cells are labelled by state and fire onJumpTo(n-1)', (
      t,
    ) async {
      final handle = t.ensureSemantics();
      _setSize(t, _wide);
      final jumps = <int>[];
      await t.pumpWidget(
        _app(
          QuestionNavigatorGrid(
            total: 6,
            index: 2,
            answered: const {0, 2},
            marked: const {2, 3},
            columns: 4,
            onJumpTo: jumps.add,
          ),
        ),
      );
      await t.pumpAndSettle();

      expect(
        find.bySemanticsLabel('Question 1, answered'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Question 2, unanswered'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Question 3, answered, marked, current'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Question 4, unanswered, marked'),
        findsOneWidget,
      );

      await t.tap(_cell(3));
      expect(jumps, [3]);
      handle.dispose();
    });
  });

  group('QuestionView homework header', () {
    testWidgets('F-4: shows mode label, progress and save status', (t) async {
      await _pump(t, size: _wide);
      expect(find.text('Homework · 20 questions'), findsOneWidget);
      expect(find.text('15 of 20 answered'), findsOneWidget);
      expect(find.text('Saved'), findsOneWidget);
    });

    for (final size in [_phone, _tablet, _wide]) {
      testWidgets(
        'F-4: homework never shows notes, hints or worked example '
        'at ${size.width.toInt()}',
        (t) async {
          await _pump(t, size: size);
          expect(find.byType(MarginNote), findsNothing);
          expect(find.byType(HintPanel), findsNothing);
          expect(find.byType(WorkedExample), findsNothing);
        },
      );
    }
  });

  for (final size in [_tablet, _wide]) {
    group('QuestionView homework panel at ${size.width.toInt()}', () {
      testWidgets('F-4: side panel is 280 px wide on the right', (t) async {
        await _pump(t, size: size);
        expect(_panel, findsOneWidget);
        expect(t.getSize(_panel).width, 280);
        expect(t.getTopRight(_panel).dx, size.width);
        expect(find.byType(HomeworkNavigatorPanel), findsOneWidget);
        expect(find.byIcon(Icons.expand_less), findsNothing);
      });

      testWidgets('F-4: panel shows title, legend, summary and submit', (
        t,
      ) async {
        await _pump(t, size: size);
        expect(_inPanel(find.text('Homework 4.2')), findsOneWidget);
        expect(_inPanel(find.text('Current')), findsOneWidget);
        expect(_inPanel(find.text('Answered')), findsOneWidget);
        expect(_inPanel(find.text('Unanswered')), findsOneWidget);
        expect(
          _inPanel(
            find.text('15 of 20 answered · 5 unanswered. You can submit once.'),
          ),
          findsOneWidget,
        );
        expect(_inPanel(find.text('Submit homework')), findsOneWidget);
        expect(_inPanel(find.text('Marked for review')), findsOneWidget);
      });

      testWidgets('F-4: panel grid has 4 columns and 20 cells', (t) async {
        await _pump(t, size: size);
        for (var i = 0; i < _total; i++) {
          expect(_cell(i), findsOneWidget);
        }
        expect(t.getTopLeft(_cell(3)).dy, t.getTopLeft(_cell(0)).dy);
        expect(
          t.getTopLeft(_cell(4)).dy,
          greaterThan(t.getTopLeft(_cell(0)).dy),
        );
        expect(t.getTopLeft(_cell(4)).dx, t.getTopLeft(_cell(0)).dx);
      });

      testWidgets('F-4: tapping a panel cell fires onJumpTo(i)', (t) async {
        final calls = await _pump(t, size: size);
        await t.tap(_cell(11));
        expect(calls.jumps, [11]);
      });
    });
  }

  group('QuestionView homework phone', () {
    testWidgets('F-4: no side panel; footer button opens the sheet', (
      t,
    ) async {
      await _pump(t, size: _phone);
      expect(_panel, findsNothing);
      expect(find.byType(QuestionNavigatorGrid), findsNothing);
      expect(find.byIcon(Icons.expand_less), findsOneWidget);

      await t.tap(find.text('Question 6 of 20'));
      await t.pumpAndSettle();

      expect(find.byType(QuestionNavigatorGrid), findsOneWidget);
    });

    testWidgets('F-4: sheet has 6 columns, extra legend and submit', (
      t,
    ) async {
      await _pump(t, size: _phone);
      await t.tap(find.text('Question 6 of 20'));
      await t.pumpAndSettle();

      expect(find.text('Current'), findsOneWidget);
      expect(find.text('Answered'), findsOneWidget);
      expect(find.text('Unanswered'), findsOneWidget);
      expect(find.text('Marked for review'), findsOneWidget);
      expect(find.byIcon(Icons.bookmark), findsWidgets);
      expect(find.text('Submit homework'), findsOneWidget);
      expect(t.getTopLeft(_cell(5)).dy, t.getTopLeft(_cell(0)).dy);
      expect(
        t.getTopLeft(_cell(6)).dy,
        greaterThan(t.getTopLeft(_cell(0)).dy),
      );
    });

    testWidgets('F-4: tapping a sheet cell fires onJumpTo and closes it', (
      t,
    ) async {
      final calls = await _pump(t, size: _phone);
      await t.tap(find.text('Question 6 of 20'));
      await t.pumpAndSettle();

      await t.tap(_cell(11));
      await t.pumpAndSettle();

      expect(calls.jumps, [11]);
      expect(find.byType(QuestionNavigatorGrid), findsNothing);
    });
  });

  group('QuestionView homework width changes', () {
    testWidgets(
      'F-4: resizing 1280 to 360 swaps panel for sheet button and keeps '
      'onJumpTo',
      (t) async {
        final calls = await _pump(t, size: _wide);
        expect(_panel, findsOneWidget);
        await t.tap(_cell(3));
        expect(calls.jumps, [3]);

        t.view.physicalSize = _phone;
        await t.pumpAndSettle();

        expect(_panel, findsNothing);
        expect(find.byType(QuestionNavigatorGrid), findsNothing);
        expect(t.takeException(), isNull);

        await t.tap(find.text('Question 6 of 20'));
        await t.pumpAndSettle();
        expect(find.byType(QuestionNavigatorGrid), findsOneWidget);

        await t.tap(_cell(12));
        await t.pumpAndSettle();

        expect(calls.jumps, [3, 12]);
        expect(find.byType(QuestionNavigatorGrid), findsNothing);
      },
    );
  });

  group('QuestionView homework submit dialog', () {
    testWidgets('F-4: shows copy and a chip per unanswered question', (
      t,
    ) async {
      await _pump(t, size: _wide);
      await _openSubmitDialog(t);

      expect(_dialog, findsOneWidget);
      expect(t.widget<BookletDialog>(_dialog).title, 'Submit homework?');
      expect(
        _inDialog(
          find.text(
            'You can submit once. After that your answers are locked and '
            'marked.',
          ),
        ),
        findsOneWidget,
      );
      expect(_inDialog(find.text('5 questions unanswered')), findsOneWidget);
      expect(
        _inDialog(find.text('Select one to go back to it.')),
        findsOneWidget,
      );
      for (final chip in _unansweredChips) {
        expect(_inDialog(find.text(chip)), findsOneWidget);
      }
      expect(_inDialog(find.text('Q1')), findsNothing);
      expect(_inDialog(find.text('Q6')), findsNothing);
    });

    testWidgets('F-4: tapping a chip pops the dialog and jumps to it', (
      t,
    ) async {
      final calls = await _pump(t, size: _wide);
      await _openSubmitDialog(t);

      await t.tap(_inDialog(find.text('Q14')));
      await t.pumpAndSettle();

      expect(calls.jumps, [13]);
      expect(calls.submits, 0);
      expect(_dialog, findsNothing);
    });

    testWidgets('F-4: Keep working pops and calls nothing', (t) async {
      final calls = await _pump(t, size: _wide);
      await _openSubmitDialog(t);

      await t.tap(_inDialog(find.text('Keep working')));
      await t.pumpAndSettle();

      expect(_dialog, findsNothing);
      expect(calls.jumps, isEmpty);
      expect(calls.submits, 0);
    });

    testWidgets('F-4: confirming pops and calls onSubmit once', (t) async {
      final calls = await _pump(t, size: _wide);
      await _openSubmitDialog(t);

      await t.tap(_inDialog(find.text('Submit homework')));
      await t.pumpAndSettle();

      expect(_dialog, findsNothing);
      expect(calls.submits, 1);
      expect(calls.jumps, isEmpty);
    });

    testWidgets('F-4: with everything answered there is no unanswered list', (
      t,
    ) async {
      await _pump(
        t,
        size: _wide,
        mode: _mode(answered: {for (var i = 0; i < _total; i++) i}),
      );
      await _openSubmitDialog(t);

      expect(_dialog, findsOneWidget);
      expect(_inDialog(find.textContaining('unanswered')), findsNothing);
      expect(
        _inDialog(find.text('Select one to go back to it.')),
        findsNothing,
      );
      expect(_inDialog(find.text('Q1')), findsNothing);
    });

    testWidgets('F-4: phone sheet submit also opens the dialog', (t) async {
      await _pump(t, size: _phone);
      await t.tap(find.text('Question 6 of 20'));
      await t.pumpAndSettle();

      await t.tap(find.text('Submit homework'));
      await t.pumpAndSettle();

      expect(t.widget<BookletDialog>(_dialog).title, 'Submit homework?');
    });
  });

  group('QuestionView homework footer bounds', () {
    for (final size in [_phone, _wide]) {
      final w = size.width.toInt();

      testWidgets('F-4: Back is disabled at the first question at $w', (
        t,
      ) async {
        final calls = await _pump(t, size: size, mode: _mode(index: 0));
        expect(_button(t, 'Back').onPressed, isNull);
        expect(_button(t, 'Next').onPressed, isNotNull);
        await t.tap(find.text('Back'), warnIfMissed: false);
        expect(calls.prevs, 0);
      });

      testWidgets('F-4: Next is disabled at the last question at $w', (
        t,
      ) async {
        final calls = await _pump(
          t,
          size: size,
          mode: _mode(index: _total - 1),
        );
        expect(_button(t, 'Next').onPressed, isNull);
        expect(_button(t, 'Back').onPressed, isNotNull);
        await t.tap(find.text('Next'), warnIfMissed: false);
        expect(calls.nexts, 0);
      });

      testWidgets('F-4: Back and Next fire mid-way at $w', (t) async {
        final calls = await _pump(t, size: size);
        await t.tap(find.text('Back'));
        await t.tap(find.text('Next'));
        expect(calls.prevs, 1);
        expect(calls.nexts, 1);
      });
    }
  });

  group('QuestionView homework save status', () {
    const copy = {
      SaveStatus.saving: 'Saving…',
      SaveStatus.saved: 'Saved',
      SaveStatus.offline: 'Offline — will sync',
      SaveStatus.failed: "Couldn't save",
    };

    for (final entry in copy.entries) {
      testWidgets('F-4: ${entry.key.name} renders "${entry.value}"', (
        t,
      ) async {
        _setSize(t, _phone);
        final calls = _Calls();
        await t.pumpWidget(_app(_view(calls, _mode(status: entry.key))));
        // "Saving…" has a spinner that never settles.
        await t.pump();
        expect(find.text(entry.value), findsOneWidget);
        expect(
          find.text('Retry'),
          entry.key == SaveStatus.failed ? findsOneWidget : findsNothing,
        );
      });
    }

    testWidgets('F-4: Retry fires onRetrySave', (t) async {
      final calls = await _pump(
        t,
        size: _wide,
        mode: _mode(status: SaveStatus.failed),
      );
      await t.tap(find.text('Retry'));
      expect(calls.retries, 1);
    });
  });

  group('QuestionView homework final review regressions', () {
    for (final size in [const Size(1024, 800), _wide]) {
      testWidgets(
        'F-4: choice column uses the available width at ${size.width.toInt()}',
        (t) async {
          await _pump(t, size: size);
          final bodyWidth = size.width - 280;
          final avail = bodyWidth - 2 * 32;
          final expected = avail < 720 ? avail : 720.0;
          final tile = find.byKey(const ValueKey('choice-A'));
          expect(tile, findsOneWidget);
          expect(t.getSize(tile).width, greaterThanOrEqualTo(expected));
        },
      );
    }

    testWidgets('F-4: 360 footer shows "Question 6 of 20" without ellipsis', (
      t,
    ) async {
      await _pump(t, size: _phone);
      final finder = find.text('Question 6 of 20');
      expect(finder, findsOneWidget);
      final paragraph = t.renderObject<RenderParagraph>(finder);
      expect(paragraph.didExceedMaxLines, isFalse);
    });

    testWidgets('F-4: sheet cell is inert when onJumpTo is null', (t) async {
      _setSize(t, _phone);
      await t.pumpWidget(
        _app(
          QuestionView(
            title: 'Homework 4.2',
            question: _question,
            mode: _mode(),
            answer: const AnswerState(),
            onNext: () {},
            onPrev: () {},
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Question 6 of 20'));
      await t.pumpAndSettle();
      expect(find.byType(QuestionNavigatorGrid), findsOneWidget);

      await t.tap(_cell(0));
      await t.pumpAndSettle();

      expect(find.byType(QuestionNavigatorGrid), findsOneWidget);
    });
  });

  testWidgets('F-4: homework body is top-aligned at 1280', (t) async {
    await _pump(t, size: _wide);

    final headerBottom = t.getRect(find.byType(QuestionHeader)).bottom;
    final exerciseTop = t.getRect(find.byType(ExerciseHeader)).top;
    expect(exerciseTop - headerBottom, lessThanOrEqualTo(48));
  });
}
