import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:sat_east_client/core/di/injection.dart';
import 'package:sat_east_client/core/router/app_router.dart';
import 'package:sat_east_client/core/theme/booklet_tokens.dart';
import 'package:sat_east_client/features/teacher/videos/presentation/cubit/teacher_videos_cubit.dart';
import 'package:sat_east_client/features/teacher/videos/presentation/cubit/teacher_videos_state.dart';
import 'package:sat_east_client/features/teacher/videos/presentation/teacher_videos_copy.dart';
import 'package:sat_east_client/features/teacher/videos/presentation/widgets/teacher_videos_content.dart';

class TeacherVideosScreen extends StatelessWidget {
  const TeacherVideosScreen({
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
      final cubit = getIt<TeacherVideosCubit>();
      unawaited(cubit.load(topicId));
      return cubit;
    },
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(BookletSpace.s4),
          child: Row(
            children: [
              BackButton(
                onPressed: () => context.go(
                  '${AppRoutes.teacher}/courses/${Uri.encodeComponent(courseId)}',
                ),
              ),
              Expanded(
                child: Text(
                  TeacherVideosCopy.title,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: BookletStroke.thin),
        Expanded(
          child: BlocConsumer<TeacherVideosCubit, TeacherVideosState>(
            listener: (context, state) {
              if (state case TeacherVideosReady(error: final error?)) {
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    SnackBar(
                      content: Text(TeacherVideosCopy.error(error.code)),
                    ),
                  );
              }
            },
            builder: (context, state) => switch (state) {
              TeacherVideosLoading() => const Center(
                child: CircularProgressIndicator(),
              ),
              TeacherVideosFailed(:final error) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(BookletSpace.s4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(TeacherVideosCopy.error(error.code)),
                      TextButton(
                        onPressed: () => unawaited(
                          context.read<TeacherVideosCubit>().load(topicId),
                        ),
                        child: const Text(TeacherVideosCopy.retry),
                      ),
                    ],
                  ),
                ),
              ),
              TeacherVideosReady() => TeacherVideosContent(
                state: state,
                onReload: () =>
                    unawaited(context.read<TeacherVideosCubit>().load(topicId)),
              ),
            },
          ),
        ),
      ],
    ),
  );
}
