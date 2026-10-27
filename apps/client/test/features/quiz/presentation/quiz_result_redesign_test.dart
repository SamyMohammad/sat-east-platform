import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/theme/app_icons.dart';
import 'package:sat_east_client/core/theme/app_motion.dart';
import 'package:sat_east_client/core/theme/app_theme.dart';
import 'package:sat_east_client/features/quiz/domain/entities/quiz.dart';
import 'package:sat_east_client/features/quiz/presentation/screens/quiz_result_screen.dart';
import 'package:sat_east_client/shared/widgets/app_illustration.dart';

const passedReport = QuizReport(
  scoreRaw: 9,
  scoreTotal: 12,
  scorePct: 75,
  passMark: 70,
  passed: true,
  nextTopic: null,
  retakeAt: null,
);
const failedReport = QuizReport(
  scoreRaw: 8,
  scoreTotal: 12,
  scorePct: 66.67,
  passMark: 70,
  passed: false,
  nextTopic: null,
  retakeAt: null,
);

Future<void> pumpResult(
  WidgetTester tester, {
  QuizReport report = passedReport,
  bool reduced = false,
  double width = 360,
  double textScale = 1,
}) async {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations: reduced,
          textScaler: TextScaler.linear(textScale),
        ),
        child: child!,
      ),
      home: Scaffold(
        body: QuizResultScreen(topicId: 't1', report: report),
      ),
    ),
  );
}

void main() {
  testWidgets('quiz_result_count_up_reaches_final_score', (tester) async {
    await pumpResult(tester);
    expect(find.text('0%'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 100));
    final interim = tester
        .widget<Text>(find.byKey(const ValueKey('quiz-score')))
        .data!;
    expect(interim, isNot('0%'));
    expect(interim, isNot('75%'));
    await tester.pump(AppMotion.signature - const Duration(milliseconds: 100));
    expect(find.text('75%'), findsOneWidget);
    final badge = find.byKey(const ValueKey('quiz-result-badge'));
    expect(
      tester
          .widget<FadeTransition>(
            find
                .ancestor(of: badge, matching: find.byType(FadeTransition))
                .first,
          )
          .opacity
          .value,
      0,
    );
    await tester.pump(AppMotion.enter);
    expect(
      tester
          .widget<FadeTransition>(
            find
                .ancestor(of: badge, matching: find.byType(FadeTransition))
                .first,
          )
          .opacity
          .value,
      1,
    );
    expect(
      tester
          .widget<ScaleTransition>(
            find
                .ancestor(of: badge, matching: find.byType(ScaleTransition))
                .first,
          )
          .scale
          .value,
      1,
    );
  });
  testWidgets('quiz_result_reduced_motion_shows_final', (tester) async {
    await pumpResult(tester, reduced: true);
    expect(find.text('75%'), findsOneWidget);
    final badge = find.byKey(const ValueKey('quiz-result-badge'));
    expect(
      tester
          .widget<FadeTransition>(
            find
                .ancestor(of: badge, matching: find.byType(FadeTransition))
                .first,
          )
          .opacity
          .value,
      1,
    );
    expect(
      tester
          .widget<ScaleTransition>(
            find
                .ancestor(of: badge, matching: find.byType(ScaleTransition))
                .first,
          )
          .scale
          .value,
      1,
    );
  });
  testWidgets('quiz_result_pass_shows_icon_and_word', (tester) async {
    await pumpResult(tester, reduced: true);
    final badge = find.byKey(const ValueKey('quiz-result-badge'));
    expect(
      find.descendant(of: badge, matching: find.byIcon(AppIcons.correct)),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: badge,
        matching: find.text('Quiz passed', findRichText: true),
      ),
      findsOneWidget,
    );
    expect(tester.widget<Semantics>(badge).properties.liveRegion, isTrue);
  });
  testWidgets('quiz_result_fail_shows_retry_illustration', (tester) async {
    await pumpResult(tester, report: failedReport, reduced: true);
    expect(
      tester.widget<AppIllustration>(find.byType(AppIllustration)).name,
      AppIllustrationName.quizRetry,
    );
    expect(find.byIcon(AppIcons.retry), findsOneWidget);
    expect(find.text('66.67%'), findsOneWidget);
  });
  for (final report in [passedReport, failedReport]) {
    testWidgets('quiz result ${report.passed} fits 360 at 2x text', (
      tester,
    ) async {
      await pumpResult(tester, report: report, reduced: true, textScale: 2);
      expect(tester.takeException(), isNull);
      final action = find.text(
        report.passed ? 'Back to course' : 'Back to topic',
      );
      await tester.ensureVisible(action);
      expect(action.hitTestable(), findsOneWidget);
    });
  }
}
