import 'package:flutter/material.dart';
import 'package:sat_east_client/features/teacher/questions/domain/entities/question_draft.dart';
import 'package:sat_east_client/shared/widgets/question_view/answer_state.dart';
import 'package:sat_east_client/shared/widgets/question_view/practice_feedback.dart';
import 'package:sat_east_client/shared/widgets/question_view/question_data.dart';
import 'package:sat_east_client/shared/widgets/question_view/question_view.dart';
import 'package:sat_east_client/shared/widgets/question_view/question_view_mode.dart';

/// Teacher-only preview of a question draft: the shared [QuestionView] in
/// practice mode with correct feedback and the explanation.
class TeacherQuestionPreview extends StatelessWidget {
  const TeacherQuestionPreview({
    required this.draft,
    this.title = 'Preview',
    super.key,
  });

  final QuestionDraft draft;
  final String title;

  @override
  Widget build(BuildContext context) => QuestionView(
    title: title,
    showNavigation: false,
    question: QuestionData(
      id: draft.id ?? 'preview',
      label: draft.externalRef.isEmpty ? 'Question preview' : draft.externalRef,
      stemMd: draft.stemMd,
      kind: draft.type == 'spr'
          ? const SprKind()
          : McqKind([
              for (final c in draft.choices)
                ChoiceData(label: c.label, md: c.body),
            ]),
      imagePaths: draft.images,
      skill: draft.skillCodes.firstOrNull,
      difficulty: switch (draft.difficulty) {
        'E' => QuestionDifficulty.easy,
        'M' => QuestionDifficulty.medium,
        'H' => QuestionDifficulty.hard,
        _ => null,
      },
    ),
    mode: PracticeMode(
      feedback: Correct(
        explanationMd: draft.explanationMd.isEmpty ? null : draft.explanationMd,
      ),
      rep: 1,
      repTarget: 1,
    ),
    answer: draft.type == 'spr'
        ? AnswerState(sprText: draft.accepted.firstOrNull ?? '')
        : AnswerState(
            selected: draft.keyChoice.isEmpty ? null : draft.keyChoice,
          ),
  );
}
