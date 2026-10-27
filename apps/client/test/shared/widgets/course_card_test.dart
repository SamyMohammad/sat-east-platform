import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/theme/app_hues.dart';
import 'package:sat_east_client/core/theme/app_theme.dart';
import 'package:sat_east_client/shared/widgets/course_card.dart';
import 'package:sat_east_client/shared/widgets/icon_tile.dart';
import 'package:sat_east_client/shared/widgets/topic_number_tile.dart';

Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(
  MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(body: SingleChildScrollView(child: child)),
  ),
);

void main() {
  testWidgets('CourseCard shows cover, tile, text and a working action', (
    tester,
  ) async {
    var taps = 0;
    await _pump(
      tester,
      CourseCard(
        hue: SubjectHue.teal,
        coverKey: const ValueKey('cover'),
        title: 'SAT Math',
        body: 'Build your math skills.',
        meta: '5 topics',
        actionLabel: 'See the syllabus',
        onAction: () => taps++,
      ),
    );
    expect(find.byKey(const ValueKey('cover')), findsOneWidget);
    expect(tester.widget<IconTile>(find.byType(IconTile)).hue, SubjectHue.teal);
    expect(find.text('SAT Math'), findsOneWidget);
    expect(find.text('Build your math skills.'), findsOneWidget);
    expect(find.text('5 topics'), findsOneWidget);
    await tester.tap(find.text('See the syllabus'));
    expect(taps, 1);
  });

  testWidgets('CourseCard without an action renders no button', (
    tester,
  ) async {
    await _pump(tester, const CourseCard(title: 'SAT Math'));
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('TopicNumberTile shows the number inside a 40 px tile', (
    tester,
  ) async {
    await _pump(tester, const TopicNumberTile('1.1', hue: SubjectHue.violet));
    expect(find.text('1.1'), findsOneWidget);
    expect(tester.getSize(find.byType(TopicNumberTile)), const Size(40, 40));
    expect(find.byType(Icon), findsNothing);
  });
}
