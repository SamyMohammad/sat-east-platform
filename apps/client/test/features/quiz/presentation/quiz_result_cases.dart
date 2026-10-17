part of 'quiz_view_test.dart';

void _resultTests() {
  for (final width in [360.0, 1280.0]) {
    testWidgets('PRC-03: passed result fits $width and opens next topic', (
      tester,
    ) async {
      final router = await _pump(
        tester,
        _cubit(const QuizLoading()),
        report: _passed,
        width: width,
      );
      expect(find.text('Quiz passed'), findsOneWidget);
      expect(find.text('9 of 12 correct · 75%'), findsOneWidget);
      expect(find.text('Pass mark 70%'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Next topic'));
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.path,
        '/courses/topics/t2',
      );
    });

    testWidgets(
      'PRC-03: failed result fits $width with localized retake time',
      (tester) async {
        final retake = DateTime.utc(2026, 10, 18, 12, 30);
        final report = QuizReport(
          scoreRaw: 8,
          scoreTotal: 12,
          scorePct: 66.67,
          passMark: 70,
          passed: false,
          nextTopic: null,
          retakeAt: retake,
        );
        final router = await _pump(
          tester,
          _cubit(const QuizLoading()),
          report: report,
          width: width,
        );
        final context = tester.element(find.byType(QuizResultScreen));
        final local = retake.toLocal();
        final l10n = MaterialLocalizations.of(context);
        final date = l10n.formatMediumDate(local);
        final time = l10n.formatTimeOfDay(
          TimeOfDay.fromDateTime(local),
          alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
        );
        expect(find.text('Quiz not passed'), findsOneWidget);
        expect(find.text('8 of 12 correct · 66.67%'), findsOneWidget);
        expect(
          find.text('You can retake it after $date $time.'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Back to topic'));
        await tester.pumpAndSettle();
        expect(
          router.routeInformationProvider.value.uri.path,
          '/courses/topics/t1',
        );
      },
    );
  }

  testWidgets('PRC-03: final-topic pass returns to course', (tester) async {
    const report = QuizReport(
      scoreRaw: 9,
      scoreTotal: 12,
      scorePct: 75,
      passMark: 70,
      passed: true,
      nextTopic: null,
      retakeAt: null,
    );
    final router = await _pump(
      tester,
      _cubit(const QuizLoading()),
      report: report,
    );
    expect(find.text('Next topic'), findsNothing);
    await tester.tap(find.text('Back to course'));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/courses');
  });

  testWidgets('PRC-03: nullable retake time keeps failed result usable', (
    tester,
  ) async {
    const report = QuizReport(
      scoreRaw: 0,
      scoreTotal: 12,
      scorePct: 0,
      passMark: 70,
      passed: false,
      nextTopic: null,
      retakeAt: null,
    );
    await _pump(tester, _cubit(const QuizLoading()), report: report);
    expect(find.text('Quiz not passed'), findsOneWidget);
    expect(find.text('Back to topic'), findsOneWidget);
    expect(find.textContaining('null'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
