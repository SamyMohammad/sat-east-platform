import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sat_east_client/features/teacher/questions/domain/entities/question_draft.dart';
import 'package:sat_east_client/features/teacher/questions/presentation/cubit/question_editor_cubit.dart';
import 'package:sat_east_client/features/teacher/questions/presentation/cubit/question_editor_state.dart';
import 'package:sat_east_client/shared/widgets/question_view/answer_state.dart';
import 'package:sat_east_client/shared/widgets/question_view/practice_feedback.dart';
import 'package:sat_east_client/shared/widgets/question_view/question_data.dart';
import 'package:sat_east_client/shared/widgets/question_view/question_view.dart';
import 'package:sat_east_client/shared/widgets/question_view/question_view_mode.dart';

class EditorPreview extends StatelessWidget {
  const EditorPreview({super.key});
  @override
  Widget build(BuildContext context) =>
      BlocSelector<QuestionEditorCubit, QuestionEditorState, QuestionDraft?>(
        selector: (s) => s.draft,
        builder: (context, draft) {
          if (draft == null) return const SizedBox.shrink();
          return QuestionView(
            title: 'Preview',
            question: QuestionData(
              id: draft.id ?? 'preview',
              label: draft.externalRef.isEmpty
                  ? 'Question preview'
                  : draft.externalRef,
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
                explanationMd: draft.explanationMd.isEmpty
                    ? null
                    : draft.explanationMd,
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
        },
      );
}
