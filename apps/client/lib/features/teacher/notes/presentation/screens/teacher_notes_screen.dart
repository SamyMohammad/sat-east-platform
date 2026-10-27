import 'dart:async';

import 'package:flutter/material.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:sat_east_client/core/di/injection.dart';
import 'package:sat_east_client/core/router/app_router.dart';
import 'package:sat_east_client/core/theme/app_tokens.dart';
import 'package:sat_east_client/features/teacher/notes/presentation/cubit/teacher_notes_cubit.dart';
import 'package:sat_east_client/features/teacher/notes/presentation/cubit/teacher_notes_state.dart';
import 'package:sat_east_client/features/teacher/notes/presentation/teacher_notes_copy.dart';
import 'package:sat_east_client/features/teacher/notes/presentation/widgets/teacher_notes_content.dart';
import 'package:sat_east_client/shared/widgets/app_skeleton.dart';
import 'package:sat_east_client/shared/widgets/error_retry.dart';

class TeacherNotesScreen extends StatelessWidget {
  const TeacherNotesScreen({
    required this.courseId,
    required this.topicId,
    super.key,
  });
  final String courseId;
  final String topicId;
  @override
  Widget build(BuildContext context) => BlocProvider(
    key: ValueKey(topicId),
    create: (_) {
      final cubit = getIt<TeacherNotesCubit>();
      unawaited(cubit.load(topicId));
      return cubit;
    },
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpace.s4),
          child: Row(
            children: [
              BackButton(
                onPressed: () => context.go(
                  '${AppRoutes.teacher}/courses/${Uri.encodeComponent(courseId)}',
                ),
              ),
              Expanded(
                child: Text(
                  'Notes',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: AppStroke.thin),
        Expanded(
          child: BlocConsumer<TeacherNotesCubit, TeacherNotesState>(
            listener: (context, state) {
              if (state case TeacherNotesReady(error: final error?)) {
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    SnackBar(content: Text(teacherNotesError(error.code))),
                  );
              }
            },
            builder: (context, state) => switch (state) {
              TeacherNotesLoading() => const Center(
                child: AppSkeleton(),
              ),
              TeacherNotesFailed(:final error) => ErrorRetry(
                title: teacherNotesError(error.code),
                message: '',
                onRetry: () =>
                    unawaited(context.read<TeacherNotesCubit>().load(topicId)),
              ),
              TeacherNotesReady() => TeacherNotesContent(state: state),
            },
          ),
        ),
      ],
    ),
  );
}
