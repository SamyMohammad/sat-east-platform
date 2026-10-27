import 'dart:async';

import 'package:flutter/material.dart';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:sat_east_client/core/theme/app_tokens.dart';
import 'package:sat_east_client/features/teacher/questions/presentation/cubit/question_editor_cubit.dart';
import 'package:sat_east_client/features/teacher/questions/presentation/cubit/question_editor_state.dart';
import 'package:sat_east_client/features/teacher/shell/teacher_save_surface.dart';
import 'package:sat_east_client/shared/widgets/loading_button.dart';

class EditorSaveBar extends StatelessWidget {
  const EditorSaveBar({super.key});
  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<QuestionEditorCubit, QuestionEditorState>(
    buildWhen: (p, n) =>
        p.isDirty != n.isDirty ||
        p.saving != n.saving ||
        p.conflict != n.conflict ||
        p.error != n.error,
    builder: (context, state) {
      if (!state.isDirty) return const SizedBox.shrink();
      final cubit = context.read<QuestionEditorCubit>();
      return TeacherSaveSurface(
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.s4),
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: AppSpace.s3,
              runSpacing: AppSpace.s3,
              children: [
                TextButton(
                  onPressed: state.saving ? null : cubit.discard,
                  child: const Text('Discard'),
                ),
                LoadingButton(
                  label: 'Save',
                  isLoading: state.saving,
                  onPressed: state.conflict
                      ? null
                      : () => unawaited(cubit.save()),
                  errorText: state.error == null
                      ? null
                      : "Couldn't save. Check your connection and try again.",
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
