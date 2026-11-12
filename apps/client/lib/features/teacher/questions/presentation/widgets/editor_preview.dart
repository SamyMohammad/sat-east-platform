import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sat_east_client/features/teacher/questions/domain/entities/question_draft.dart';
import 'package:sat_east_client/features/teacher/questions/presentation/cubit/question_editor_cubit.dart';
import 'package:sat_east_client/features/teacher/questions/presentation/cubit/question_editor_state.dart';
import 'package:sat_east_client/features/teacher/questions/presentation/widgets/teacher_question_preview.dart';

class EditorPreview extends StatelessWidget {
  const EditorPreview({super.key});
  @override
  Widget build(BuildContext context) =>
      BlocSelector<QuestionEditorCubit, QuestionEditorState, QuestionDraft?>(
        selector: (s) => s.draft,
        builder: (context, draft) => draft == null
            ? const SizedBox.shrink()
            : TeacherQuestionPreview(draft: draft),
      );
}
