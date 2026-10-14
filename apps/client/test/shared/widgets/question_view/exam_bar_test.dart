import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/theme/app_theme.dart';
import 'package:sat_east_client/core/theme/booklet_colors.dart';
import 'package:sat_east_client/shared/widgets/question_view/parts/exam_bar.dart';
import 'package:sat_east_client/shared/widgets/question_view/parts/exam_clock.dart';
import 'package:sat_east_client/shared/widgets/question_view/parts/quiz_question_header.dart';

Future<void> pump(
  WidgetTester tester,
  Widget child, {
  double width = 360,
  double textScale = 1,
}) async {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      builder: (context, app) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: app!,
      ),
      home: Scaffold(
        body: Align(alignment: Alignment.topCenter, child: child),
      ),
    ),
  );
}

ExamBar bar({
  bool compact = false,
  bool warning = false,
  bool timerHidden = false,
  Duration remaining = const Duration(minutes: 14, seconds: 30),
  String title = 'Quiz · 4.2 Linear equations',
  String shortTitle = 'Quiz 4.2',
  VoidCallback? onToggleTimer,
}) => ExamBar(
  title: title,
  shortTitle: shortTitle,
  subtitle: '12 questions',
  remaining: remaining,
  timeBudget: const Duration(minutes: 18),
  warning: warning,
  timerHidden: timerHidden,
  compact: compact,
  onToggleTimer: onToggleTimer,
);

Iterable<Semantics> semanticsWithLabel(WidgetTester tester, String label) =>
    tester
        .widgetList<Semantics>(find.byType(Semantics))
        .where(
          (s) => s.properties.label == label,
        );

Color? clockColor(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text)).style?.color;

void main() {
  const colors = BookletColors.light;

  group('F-4: formatClock', () {
    test('F-4: negative duration clamps to 00:00', () {
      expect(formatClock(const Duration(seconds: -5)), '00:00');
    });

    test('F-4: zero is 00:00', () {
      expect(formatClock(Duration.zero), '00:00');
    });

    test('F-4: partial seconds round up (280.2 s -> 04:41)', () {
      expect(formatClock(const Duration(milliseconds: 280200)), '04:41');
    });

    test('F-4: 14 minutes 30 seconds', () {
      expect(formatClock(const Duration(minutes: 14, seconds: 30)), '14:30');
    });

    test('F-4: 3600 s is 60:00', () {
      expect(formatClock(const Duration(seconds: 3600)), '60:00');
    });

    test('F-4: minutes are unbounded (4000 s -> 66:40)', () {
      expect(formatClock(const Duration(seconds: 4000)), '66:40');
    });
  });

  group('F-4: budgetFraction', () {
    const budget = Duration(minutes: 18);

    test('F-4: half elapsed is 0.5', () {
      expect(budgetFraction(const Duration(minutes: 9), budget), 0.5);
    });

    test('F-4: nothing elapsed is 0', () {
      expect(budgetFraction(budget, budget), 0);
    });

    test('F-4: remaining above budget clamps to 0', () {
      expect(budgetFraction(const Duration(minutes: 30), budget), 0);
    });

    test('F-4: negative remaining clamps to 1', () {
      expect(budgetFraction(const Duration(minutes: -3), budget), 1);
    });

    test('F-4: zero budget is full', () {
      expect(budgetFraction(Duration.zero, Duration.zero), 1);
    });

    test('F-4: negative budget is full', () {
      expect(
        budgetFraction(const Duration(minutes: 1), const Duration(minutes: -1)),
        1,
      );
    });
  });

  group('F-4: ExamBar phone', () {
    testWidgets('F-4: shows short title, subtitle and clock', (tester) async {
      await pump(tester, bar(compact: true));

      expect(find.text('Quiz 4.2'), findsOneWidget);
      expect(find.text('12 questions'), findsOneWidget);
      expect(find.text('14:30'), findsOneWidget);
    });

    testWidgets('F-4: has no Hide button even with onToggleTimer', (
      tester,
    ) async {
      await pump(tester, bar(compact: true, onToggleTimer: () {}));

      expect(find.text('Hide'), findsNothing);
      expect(find.text('Show'), findsNothing);
    });
  });

  group('F-4: ExamBar wide', () {
    testWidgets('F-4: Hide fires onToggleTimer', (tester) async {
      var taps = 0;
      await pump(tester, bar(onToggleTimer: () => taps++), width: 1280);

      expect(find.text('14:30'), findsOneWidget);
      await tester.tap(find.text('Hide'));
      expect(taps, 1);
    });

    testWidgets('F-4: no Hide button when onToggleTimer is null', (
      tester,
    ) async {
      await pump(tester, bar(), width: 1280);

      expect(find.text('Hide'), findsNothing);
    });

    testWidgets('F-4: hidden timer shows Timer hidden + Show and no clock', (
      tester,
    ) async {
      var taps = 0;
      await pump(
        tester,
        bar(timerHidden: true, onToggleTimer: () => taps++),
        width: 1280,
      );

      expect(find.text('Timer hidden'), findsOneWidget);
      expect(find.byIcon(Icons.timer_off), findsOneWidget);
      expect(find.text('14:30'), findsNothing);
      expect(find.text('Hide'), findsNothing);
      await tester.tap(find.text('Show'));
      expect(taps, 1);
    });
  });

  group('F-4: ExamBar warning', () {
    testWidgets('F-4: clock uses examBarWarning and schedule icon shows', (
      tester,
    ) async {
      await pump(
        tester,
        bar(warning: true, remaining: const Duration(minutes: 4)),
        width: 1280,
      );

      expect(clockColor(tester, '04:00'), colors.examBarWarning);
      expect(find.byIcon(Icons.schedule), findsOneWidget);
    });

    testWidgets('F-4: no schedule icon when not warning', (tester) async {
      await pump(tester, bar(), width: 1280);

      expect(find.byIcon(Icons.schedule), findsNothing);
    });

    testWidgets('F-4: Hide is absent and clock shown when timerHidden', (
      tester,
    ) async {
      await pump(
        tester,
        bar(
          warning: true,
          timerHidden: true,
          remaining: const Duration(minutes: 4),
          onToggleTimer: () {},
        ),
        width: 1280,
      );

      expect(find.text('Hide'), findsNothing);
      expect(find.text('Show'), findsNothing);
      expect(find.text('Timer hidden'), findsNothing);
      expect(find.text('04:00'), findsOneWidget);
    });
  });

  group('F-4: exam semantics', () {
    testWidgets('F-4: clock label is "Time left 14:30" and not live', (
      tester,
    ) async {
      await pump(tester, bar(compact: true));

      final nodes = semanticsWithLabel(tester, 'Time left 14:30');
      expect(nodes, isNotEmpty);
      expect(nodes.every((s) => !(s.properties.liveRegion ?? false)), isTrue);
    });

    testWidgets('F-4: warning banner is a live region', (tester) async {
      await pump(tester, const ExamWarningBanner(warnAt: Duration(minutes: 5)));

      final live = tester
          .widgetList<Semantics>(
            find.descendant(
              of: find.byType(ExamWarningBanner),
              matching: find.byType(Semantics),
            ),
          )
          .where((s) => s.properties.liveRegion ?? false);
      expect(live, isNotEmpty);
    });
  });

  group('F-4: ExamWarningBanner', () {
    Future<void> banner(
      WidgetTester tester,
      Duration warnAt, {
      VoidCallback? onReviewMarked,
    }) => pump(
      tester,
      ExamWarningBanner(warnAt: warnAt, onReviewMarked: onReviewMarked),
    );

    testWidgets('F-4: 5 minutes reads "5 minutes left."', (tester) async {
      await banner(tester, const Duration(minutes: 5));

      expect(
        find.textContaining('5 minutes left.', findRichText: true),
        findsOneWidget,
      );
    });

    testWidgets('F-4: 1 minute reads "1 minute left."', (tester) async {
      await banner(tester, const Duration(minutes: 1));

      expect(
        find.textContaining('1 minute left.', findRichText: true),
        findsOneWidget,
      );
      expect(
        find.textContaining('1 minutes', findRichText: true),
        findsNothing,
      );
    });

    testWidgets('F-4: 90 seconds rounds up to "2 minutes left."', (
      tester,
    ) async {
      await banner(tester, const Duration(seconds: 90));

      expect(
        find.textContaining('2 minutes left.', findRichText: true),
        findsOneWidget,
      );
    });

    testWidgets('F-4: Review marked fires its callback', (tester) async {
      var taps = 0;
      await banner(
        tester,
        const Duration(minutes: 5),
        onReviewMarked: () => taps++,
      );

      await tester.tap(find.text('Review marked'));
      expect(taps, 1);
    });

    testWidgets('F-4: Review marked absent when callback is null', (
      tester,
    ) async {
      await banner(tester, const Duration(minutes: 5));

      expect(find.text('Review marked'), findsNothing);
    });
  });

  group('F-4: QuizQuestionHeader', () {
    Future<void> header(
      WidgetTester tester, {
      bool marked = false,
      VoidCallback? onMark,
    }) => pump(
      tester,
      QuizQuestionHeader(number: 4, marked: marked, onMark: onMark),
    );

    testWidgets('F-4: badge shows the question number', (tester) async {
      await header(tester, onMark: () {});

      expect(find.text('4'), findsOneWidget);
    });

    testWidgets('F-4: unmarked label fires onMark', (tester) async {
      var taps = 0;
      await header(tester, onMark: () => taps++);

      expect(find.text('Mark for review'), findsOneWidget);
      await tester.tap(find.text('Mark for review'));
      expect(taps, 1);
    });

    testWidgets('F-4: marked shows label, filled icon and toggled semantics', (
      tester,
    ) async {
      await header(tester, marked: true, onMark: () {});

      expect(find.text('Marked for review'), findsOneWidget);
      expect(find.byIcon(Icons.bookmark), findsOneWidget);
      final toggled = tester
          .widgetList<Semantics>(find.byType(Semantics))
          .where((s) => s.properties.toggled == true);
      expect(toggled, isNotEmpty);
    });

    testWidgets('F-4: unmarked semantics is toggled false', (tester) async {
      await header(tester, onMark: () {});

      final toggled = tester
          .widgetList<Semantics>(find.byType(Semantics))
          .where((s) => s.properties.toggled == true);
      expect(toggled, isEmpty);
      expect(find.byIcon(Icons.bookmark_border), findsOneWidget);
    });

    testWidgets('F-4: null onMark disables the toggle', (tester) async {
      await header(tester);

      final button = tester.widget<ButtonStyleButton>(
        find.ancestor(
          of: find.text('Mark for review'),
          matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
        ),
      );
      expect(button.onPressed, isNull);
    });
  });

  group('F-4: ExamBar phone at 360 px / 2x text', () {
    testWidgets('F-4: long title ellipsizes and the clock is not clipped', (
      tester,
    ) async {
      await pump(
        tester,
        bar(compact: true, title: 'Q' * 60, shortTitle: 'S' * 60),
        textScale: 2,
      );

      expect(tester.takeException(), isNull);
      final barRect = tester.getRect(find.byType(ExamBar));
      final clockRect = tester.getRect(find.text('14:30'));
      expect(barRect.contains(clockRect.topLeft), isTrue);
      expect(barRect.contains(clockRect.bottomRight), isTrue);
      expect(clockRect.left, greaterThanOrEqualTo(0));
      expect(clockRect.right, lessThanOrEqualTo(360));
    });
  });
}
