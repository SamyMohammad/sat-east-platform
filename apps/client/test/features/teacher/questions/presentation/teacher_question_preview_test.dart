import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/theme/app_theme.dart';
import 'package:sat_east_client/features/teacher/questions/domain/entities/question_draft.dart';
import 'package:sat_east_client/features/teacher/questions/presentation/widgets/teacher_question_preview.dart';
import 'package:sat_east_client/shared/widgets/question_view/question_view.dart';

Future<void> _pump(WidgetTester tester, QuestionDraft draft) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1280, 1000);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: TeacherQuestionPreview(draft: draft)),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('MCK-03: MCQ draft shows stem, four choices and explanation', (
    tester,
  ) async {
    await _pump(
      tester,
      QuestionDraft(
        id: 'q1',
        stemMd: 'Stem sentence here',
        explanationMd: 'Because of the explanation',
        keyChoice: 'B',
        choices: const [
          DraftChoice(label: 'A', body: 'Alpha body'),
          DraftChoice(label: 'B', body: 'Bravo body'),
          DraftChoice(label: 'C', body: 'Charlie body'),
          DraftChoice(label: 'D', body: 'Delta body'),
        ],
      ),
    );
    expect(find.textContaining('Stem sentence here'), findsWidgets);
    for (final body in ['Alpha', 'Bravo', 'Charlie', 'Delta']) {
      expect(find.textContaining('$body body'), findsWidgets);
    }
    expect(find.textContaining('Because of the explanation'), findsWidgets);
    expect(
      tester.widget<QuestionView>(find.byType(QuestionView)).title,
      'Preview',
    );
  });

  testWidgets('MCK-03: SPR draft renders without choices', (tester) async {
    await _pump(
      tester,
      QuestionDraft(
        id: 'q2',
        type: 'spr',
        stemMd: 'Find the value',
        accepted: const ['12'],
        choices: const [
          DraftChoice(label: 'A', body: 'Hidden choice body'),
        ],
      ),
    );
    expect(find.textContaining('Find the value'), findsWidgets);
    expect(find.textContaining('Hidden choice body'), findsNothing);
  });

  testWidgets('MCK-03: custom title is shown', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 1000);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: TeacherQuestionPreview(
            draft: QuestionDraft(id: 'q3', stemMd: 'S'),
            title: 'Slot 4 preview',
          ),
        ),
      ),
    );
    await tester.pump();
    expect(
      tester.widget<QuestionView>(find.byType(QuestionView)).title,
      'Slot 4 preview',
    );
  });
}
