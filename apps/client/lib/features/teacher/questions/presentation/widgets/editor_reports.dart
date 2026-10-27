import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sat_east_client/features/teacher/questions/presentation/cubit/question_editor_cubit.dart';
import 'package:sat_east_client/features/teacher/questions/presentation/cubit/question_editor_state.dart';
import 'package:sat_east_client/features/teacher/questions/presentation/widgets/editor_form.dart';
import 'package:sat_east_client/features/teacher/review/presentation/widgets/review_reports_panel.dart';

class EditorWithReports extends StatelessWidget {
  const EditorWithReports({super.key});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      BlocSelector<QuestionEditorCubit, QuestionEditorState, String?>(
        selector: (s) => s.draft?.id,
        builder: (context, id) => id == null
            ? const SizedBox.shrink()
            : ReviewReportsPanel(key: ValueKey(id), questionId: id),
      ),
      const EditorForm(),
    ],
  );
}
