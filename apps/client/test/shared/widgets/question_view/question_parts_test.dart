import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/math_render/math_text.dart';
import 'package:sat_east_client/core/theme/app_theme.dart';
import 'package:sat_east_client/core/theme/booklet_colors.dart';
import 'package:sat_east_client/shared/widgets/booklet_chip.dart';
import 'package:sat_east_client/shared/widgets/question_view/parts/exercise_header.dart';
import 'package:sat_east_client/shared/widgets/question_view/parts/hint_panel.dart';
import 'package:sat_east_client/shared/widgets/question_view/parts/margin_note.dart';
import 'package:sat_east_client/shared/widgets/question_view/parts/question_header.dart';
import 'package:sat_east_client/shared/widgets/question_view/parts/save_status_label.dart';
import 'package:sat_east_client/shared/widgets/question_view/parts/worked_example.dart';
import 'package:sat_east_client/shared/widgets/question_view/question_data.dart';
import 'package:sat_east_client/shared/widgets/question_view/question_view_mode.dart';

Future<void> pump(
  WidgetTester tester,
  Widget child, {
  double width = 360,
}) async {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
}

QuestionHeader header({
  VoidCallback? onBack,
  String title = 'Homework 4.2',
  int? current = 2,
}) => QuestionHeader(
  title: title,
  modeLabel: 'Homework',
  progressLabel: '3 of 5',
  done: 2,
  total: 5,
  current: current,
  onBack: onBack,
);

Iterable<Semantics> liveRegions(WidgetTester tester, Finder within) => tester
    .widgetList<Semantics>(
      find.descendant(of: within, matching: find.byType(Semantics)),
    )
    .where((s) => s.properties.liveRegion ?? false);

Color? textColor(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text)).style?.color ??
    DefaultTextStyle.of(tester.element(find.text(text))).style.color;

void main() {
  group('F-4: QuestionHeader phone', () {
    testWidgets('F-4: back button has tooltip and fires onBack', (
      tester,
    ) async {
      var taps = 0;
      await pump(tester, header(onBack: () => taps++));

      expect(find.byTooltip('Back to topic'), findsOneWidget);
      await tester.tap(find.byTooltip('Back to topic'));
      expect(taps, 1);
    });

    testWidgets('F-4: long title is ellipsized on one line', (tester) async {
      await pump(tester, header(title: 'Homework ' * 20));

      final text = tester.widget<Text>(
        find.textContaining('Homework Homework'),
      );
      expect(text.overflow, TextOverflow.ellipsis);
      expect(text.maxLines, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('F-4: shows progress label and mode label', (tester) async {
      await pump(tester, header());

      expect(find.text('3 of 5'), findsOneWidget);
      expect(find.text('Homework'), findsOneWidget);
    });

    testWidgets('F-4: segment bar has one segment per question', (
      tester,
    ) async {
      await pump(tester, header());

      for (var i = 0; i < 5; i++) {
        expect(find.byKey(ValueKey('progress-segment-$i')), findsOneWidget);
      }
      expect(find.byKey(const ValueKey('progress-segment-5')), findsNothing);
    });

    testWidgets('F-4: segments are filled, outlined current, then rule', (
      tester,
    ) async {
      await pump(tester, header());

      final scheme = Theme.of(
        tester.element(find.byType(QuestionHeader)),
      ).colorScheme;
      BoxDecoration deco(int i) =>
          tester
                  .widget<Container>(
                    find.byKey(ValueKey('progress-segment-$i')),
                  )
                  .decoration!
              as BoxDecoration;

      for (final i in [0, 1]) {
        expect(deco(i).color, scheme.primary);
      }
      expect(deco(2).color, scheme.primaryContainer);
      final border = deco(2).border! as Border;
      expect(border.top.color, scheme.primary);
      expect(border.top.width, 1);
      for (final i in [3, 4]) {
        expect(deco(i).color, scheme.outlineVariant);
        expect(deco(i).border, isNull);
      }
    });

    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'F-4: failed save trailing does not overflow at 360 px, text x$scale',
        (tester) async {
          var retries = 0;
          tester.view.physicalSize = const Size(360, 800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.light(),
              home: MediaQuery.withClampedTextScaling(
                minScaleFactor: scale,
                maxScaleFactor: scale,
                child: Scaffold(
                  body: QuestionHeader(
                    title: 'Homework ' * 20,
                    modeLabel: 'Homework',
                    progressLabel: '3 of 5',
                    done: 2,
                    total: 5,
                    current: 2,
                    trailing: SaveStatusLabel(
                      status: SaveStatus.failed,
                      onRetry: () => retries++,
                    ),
                  ),
                ),
              ),
            ),
          );

          expect(tester.takeException(), isNull);
          await tester.tap(find.text('Retry'));
          expect(retries, 1);
        },
      );
    }

    testWidgets('F-4: has no overflow menu on phone', (tester) async {
      await pump(tester, header());

      expect(find.byIcon(Icons.more_vert), findsNothing);
    });
  });

  group('F-4: QuestionHeader wide', () {
    testWidgets('F-4: progress block sits right of the title', (tester) async {
      await pump(tester, header(), width: 1280);

      final title = tester.getTopLeft(find.text('Homework 4.2'));
      final progress = tester.getTopLeft(find.text('3 of 5'));
      expect(progress.dx, greaterThan(title.dx));
      expect(tester.getTopRight(find.text('3 of 5')).dx, greaterThan(640));
    });

    testWidgets('F-4: has no overflow menu on wide', (tester) async {
      await pump(tester, header(), width: 1280);

      expect(find.byIcon(Icons.more_vert), findsNothing);
    });
  });

  group('F-4: SaveStatusLabel', () {
    testWidgets('F-4: saved shows cloud_done_outlined and "Saved"', (
      tester,
    ) async {
      await pump(tester, const SaveStatusLabel(status: SaveStatus.saved));

      expect(find.byIcon(Icons.cloud_done_outlined), findsOneWidget);
      expect(find.text('Saved'), findsOneWidget);
    });

    testWidgets('F-4: saving shows a progress indicator and "Saving…"', (
      tester,
    ) async {
      await pump(tester, const SaveStatusLabel(status: SaveStatus.saving));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Saving…'), findsOneWidget);
    });

    testWidgets('F-4: offline shows cloud_off_outlined and copy', (
      tester,
    ) async {
      await pump(tester, const SaveStatusLabel(status: SaveStatus.offline));

      expect(find.byIcon(Icons.cloud_off_outlined), findsOneWidget);
      expect(find.text('Offline — will sync'), findsOneWidget);
    });

    testWidgets('F-4: failed shows error_outline_rounded and Retry', (
      tester,
    ) async {
      var retries = 0;
      await pump(
        tester,
        SaveStatusLabel(status: SaveStatus.failed, onRetry: () => retries++),
      );

      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
      expect(find.text("Couldn't save"), findsOneWidget);
      await tester.tap(find.text('Retry'));
      expect(retries, 1);
    });

    testWidgets('F-4: non-failed statuses show no Retry', (tester) async {
      await pump(tester, const SaveStatusLabel(status: SaveStatus.saved));

      expect(find.text('Retry'), findsNothing);
    });

    testWidgets('F-4: is wrapped in a live region', (tester) async {
      await pump(tester, const SaveStatusLabel(status: SaveStatus.saved));

      expect(liveRegions(tester, find.byType(SaveStatusLabel)), isNotEmpty);
    });
  });

  group('F-4: ExerciseHeader', () {
    testWidgets('F-4: label is uppercase', (tester) async {
      await pump(tester, const ExerciseHeader(label: '4.2 · Ex 7'));

      expect(find.text('4.2 · EX 7'), findsOneWidget);
    });

    for (final (difficulty, copy) in [
      (QuestionDifficulty.easy, 'E · Easy'),
      (QuestionDifficulty.medium, 'M · Medium'),
      (QuestionDifficulty.hard, 'H · Hard'),
    ]) {
      testWidgets('F-4: ${difficulty.name} chip reads "$copy"', (tester) async {
        await pump(
          tester,
          ExerciseHeader(label: '4.2 · Ex 7', difficulty: difficulty),
        );

        expect(find.text(copy), findsOneWidget);
      });
    }

    testWidgets('F-4: skill renders as a skill chip with sell icon', (
      tester,
    ) async {
      await pump(
        tester,
        const ExerciseHeader(label: '4.2 · Ex 7', skill: 'Linear equations'),
      );

      final chip = tester.widget<BookletChip>(find.byType(BookletChip));
      expect(chip.kind, BookletChipKind.skill);
      expect(chip.icon, Icons.sell_outlined);
      expect(chip.label, 'Linear equations');
    });

    testWidgets('F-4: omits chips when difficulty and skill are null', (
      tester,
    ) async {
      await pump(tester, const ExerciseHeader(label: '4.2 · Ex 7'));

      expect(find.byType(BookletChip), findsNothing);
    });
  });

  group('F-4: MarginNote', () {
    testWidgets('F-4: miss uses draw_outlined, author and error colour', (
      tester,
    ) async {
      await pump(
        tester,
        const MarginNote(
          tone: MarginNoteTone.miss,
          author: 'Mr. Samy',
          bodyMd: 'Check the sign.',
        ),
      );

      final error = Theme.of(
        tester.element(find.byType(MarginNote)),
      ).colorScheme.error;
      expect(find.byIcon(Icons.draw_outlined), findsOneWidget);
      expect(find.byIcon(Icons.edit_note_rounded), findsNothing);
      expect(find.text('Mr. Samy'), findsOneWidget);
      expect(
        tester.widget<Icon>(find.byIcon(Icons.draw_outlined)).color,
        error,
      );
      expect(textColor(tester, 'Mr. Samy'), error);
    });

    testWidgets('F-4: correct uses check_circle_rounded, "Correct", green', (
      tester,
    ) async {
      await pump(
        tester,
        const MarginNote(
          tone: MarginNoteTone.correct,
          author: null,
          bodyMd: 'Nice work.',
        ),
      );

      final green = tester.element(find.byType(MarginNote)).booklet.greenTick;
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
      expect(find.text('Correct'), findsOneWidget);
      expect(textColor(tester, 'Correct'), green);
      expect(
        tester.widget<Icon>(find.byIcon(Icons.check_circle_rounded)).color,
        green,
      );
    });

    for (final tone in MarginNoteTone.values) {
      testWidgets('F-4: ${tone.name} note is a live region', (tester) async {
        await pump(
          tester,
          MarginNote(tone: tone, author: 'Mr. Samy', bodyMd: 'Body'),
        );

        expect(liveRegions(tester, find.byType(MarginNote)), isNotEmpty);
      });
    }

    testWidgets('F-4: null author on miss shows icon only', (tester) async {
      await pump(
        tester,
        const MarginNote(
          tone: MarginNoteTone.miss,
          author: null,
          bodyMd: 'Check the sign.',
        ),
      );

      expect(find.byIcon(Icons.draw_outlined), findsOneWidget);
      expect(find.text('Mr. Samy'), findsNothing);
      expect(find.text('Correct'), findsNothing);
    });

    testWidgets('F-4: body renders through MathText', (tester) async {
      await pump(
        tester,
        const MarginNote(
          tone: MarginNoteTone.miss,
          author: 'Mr. Samy',
          bodyMd: r'Try \(x = 3\)',
        ),
      );

      expect(
        tester.widget<MathText>(find.byType(MathText)).source,
        r'Try \(x = 3\)',
      );
    });

    testWidgets('F-4: correct note renders non-empty body via MathText', (
      tester,
    ) async {
      await pump(
        tester,
        const MarginNote(
          tone: MarginNoteTone.correct,
          author: null,
          bodyMd: r'Well done \(x\)',
        ),
      );

      expect(
        tester.widget<MathText>(find.byType(MathText)).source,
        r'Well done \(x\)',
      );
    });

    for (final inline in [true, false]) {
      testWidgets(
        'F-4: ${inline ? 'inline draws top rule' : 'aside draws leading rule'}',
        (tester) async {
          await pump(
            tester,
            MarginNote(
              tone: MarginNoteTone.miss,
              author: 'Mr. Samy',
              bodyMd: 'Body',
              inline: inline,
            ),
          );

          final error = Theme.of(
            tester.element(find.byType(MarginNote)),
          ).colorScheme.error;
          final box = tester.widget<DecoratedBox>(
            find.descendant(
              of: find.byType(MarginNote),
              matching: find.byType(DecoratedBox),
            ),
          );
          final border = (box.decoration as BoxDecoration).border!;
          if (inline) {
            expect(border, isA<Border>());
            expect((border as Border).top.color, error);
            expect(border.top.width, greaterThan(0));
            expect(border.left, BorderSide.none);
          } else {
            expect(border, isA<BorderDirectional>());
            final dir = border as BorderDirectional;
            expect(dir.start.color, error);
            expect(dir.start.width, greaterThan(0));
            expect(dir.top, BorderSide.none);
          }
        },
      );
    }

    testWidgets('F-4: empty body renders header only, no MathText', (
      tester,
    ) async {
      await pump(
        tester,
        const MarginNote(
          tone: MarginNoteTone.correct,
          author: null,
          bodyMd: '',
        ),
      );

      expect(find.text('Correct'), findsOneWidget);
      expect(find.byType(MathText), findsNothing);
    });

    testWidgets('F-4: aside variant (inline false) renders', (tester) async {
      await pump(
        tester,
        const MarginNote(
          tone: MarginNoteTone.miss,
          author: 'Mr. Samy',
          bodyMd: 'Body',
          inline: false,
        ),
      );

      expect(find.text('Mr. Samy'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('F-4: HintPanel and WorkedExample', () {
    testWidgets('F-4: hint shows "HINT" and body via MathText', (tester) async {
      await pump(tester, const HintPanel(md: r'Use \(a^2\)'));

      expect(find.text('HINT'), findsOneWidget);
      expect(
        tester.widget<MathText>(find.byType(MathText)).source,
        r'Use \(a^2\)',
      );
    });

    testWidgets('F-4: worked example shows uppercase title and MathText body', (
      tester,
    ) async {
      await pump(
        tester,
        const WorkedExample(label: '4.2 · Ex 7', md: r'\(2x\)'),
      );

      expect(find.text('WORKED EXAMPLE · 4.2 · EX 7'), findsOneWidget);
      expect(tester.widget<MathText>(find.byType(MathText)).source, r'\(2x\)');
    });
  });
}
