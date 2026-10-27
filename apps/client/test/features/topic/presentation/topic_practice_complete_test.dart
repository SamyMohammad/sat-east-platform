import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/theme/app_icons.dart';
import 'package:sat_east_client/core/theme/app_theme.dart';
import 'package:sat_east_client/features/topic/domain/entities/topic_detail.dart';
import 'package:sat_east_client/features/topic/presentation/widgets/topic_content.dart';

TopicDetail _topic({required int practiceCount}) => TopicDetail(
  id: 't',
  title: 'Linear equations',
  sortLabel: '1.1',
  status: TopicStatus.open,
  practiceCount: practiceCount,
  practiceMin: 10,
  quiz: const QuizAvailable(),
);

Future<void> _pump(WidgetTester tester, TopicDetail topic) => tester.pumpWidget(
  MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(
      body: SingleChildScrollView(
        child: TopicContent(topic: topic, onPractice: () {}, onQuiz: () {}),
      ),
    ),
  ),
);

void main() {
  testWidgets('PRC-02: practice is primary until the minimum is reached', (
    tester,
  ) async {
    await _pump(tester, _topic(practiceCount: 3));
    expect(find.widgetWithText(FilledButton, 'Practice'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Practice'), findsNothing);
  });

  testWidgets('PRC-02: complete practice is secondary, Start quiz primary', (
    tester,
  ) async {
    await _pump(tester, _topic(practiceCount: 10));
    expect(find.widgetWithText(OutlinedButton, 'Practice'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Practice'), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Start quiz'), findsOneWidget);
  });

  testWidgets('LRN-02: topic page has no number kicker or inline pencil', (
    tester,
  ) async {
    await _pump(tester, _topic(practiceCount: 3));
    expect(find.text('1.1'), findsNothing);
    // The violet step tile is the only pencil on the page.
    expect(find.byIcon(AppIcons.workedExample), findsOneWidget);
  });
}
