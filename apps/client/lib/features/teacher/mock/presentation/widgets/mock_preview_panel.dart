import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sat_east_client/core/theme/app_icons.dart';
import 'package:sat_east_client/core/theme/app_tokens.dart';
import 'package:sat_east_client/features/teacher/mock/presentation/cubit/mock_form_cubit.dart';
import 'package:sat_east_client/features/teacher/mock/presentation/cubit/mock_form_state.dart';
import 'package:sat_east_client/features/teacher/mock/presentation/mock_copy.dart';
import 'package:sat_east_client/features/teacher/questions/presentation/widgets/teacher_question_preview.dart';
import 'package:sat_east_client/shared/widgets/app_skeleton.dart';
import 'package:sat_east_client/shared/widgets/error_retry.dart';

/// The single-question preview: loading, error or the question. Used as the
/// wide-screen side panel and inside the narrow-screen bottom sheet.
class MockPreviewBody extends StatelessWidget {
  const MockPreviewBody({super.key});

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<MockFormCubit, MockFormState>(
        buildWhen: (a, b) =>
            a is MockFormLoaded != b is MockFormLoaded ||
            (a is MockFormLoaded &&
                b is MockFormLoaded &&
                (a.previewId != b.previewId ||
                    a.preview != b.preview ||
                    a.previewError != b.previewError)),
        builder: (context, state) {
          if (state is! MockFormLoaded || state.previewId == null) {
            return const SizedBox.shrink();
          }
          final id = state.previewId!;
          if (state.previewError case final error?) {
            return ErrorRetry(
              title: mockErrorCopy(error.code),
              message: '',
              onRetry: () =>
                  unawaited(context.read<MockFormCubit>().openPreview(id)),
            );
          }
          if (state.preview case final draft?) {
            return TeacherQuestionPreview(
              draft: draft,
              title: mockPreviewTitle,
            );
          }
          return const Center(child: AppSkeleton());
        },
      );
}

/// Side panel for wide screens: a close button above the preview.
class MockPreviewPanel extends StatelessWidget {
  const MockPreviewPanel({super.key});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Align(
        alignment: Alignment.centerRight,
        child: IconButton(
          tooltip: mockClosePreview,
          onPressed: context.read<MockFormCubit>().closePreview,
          icon: const Icon(AppIcons.close),
        ),
      ),
      const SizedBox(height: AppSpace.s1),
      const Expanded(child: MockPreviewBody()),
    ],
  );
}
