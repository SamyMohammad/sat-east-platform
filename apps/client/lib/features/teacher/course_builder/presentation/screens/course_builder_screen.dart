import 'dart:async';

import 'package:flutter/material.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:sat_east_client/core/di/injection.dart';
import 'package:sat_east_client/core/theme/app_icons.dart';
import 'package:sat_east_client/core/theme/app_tokens.dart';
import 'package:sat_east_client/features/teacher/course_builder/presentation/course_builder_copy.dart';
import 'package:sat_east_client/features/teacher/course_builder/presentation/cubit/course_builder_cubit.dart';
import 'package:sat_east_client/features/teacher/course_builder/presentation/cubit/course_builder_state.dart';
import 'package:sat_east_client/features/teacher/course_builder/presentation/widgets/builder_tree.dart';
import 'package:sat_east_client/shared/widgets/app_illustration.dart';
import 'package:sat_east_client/shared/widgets/app_skeleton.dart';
import 'package:sat_east_client/shared/widgets/empty_state.dart';
import 'package:sat_east_client/shared/widgets/error_retry.dart';

class CourseBuilderScreen extends StatelessWidget {
  const CourseBuilderScreen({this.courseId, super.key});
  final String? courseId;
  @override
  Widget build(BuildContext context) => BlocProvider<CourseBuilderCubit>(
    key: ValueKey(courseId),
    create: (_) {
      final cubit = getIt<CourseBuilderCubit>();
      unawaited(cubit.load(courseId));
      return cubit;
    },
    child: CourseBuilderView(courseId: courseId),
  );
}

class CourseBuilderView extends StatelessWidget {
  const CourseBuilderView({this.courseId, super.key});
  final String? courseId;
  @override
  Widget build(
    BuildContext context,
  ) => BlocConsumer<CourseBuilderCubit, CourseBuilderState>(
    listener: (context, state) {
      if (state case CourseBuilderLoaded(:final tree, :final lastError)) {
        if (courseId == null && tree != null) {
          context.go('/teacher/courses/${Uri.encodeComponent(tree.courseId)}');
        }
        if (lastError != null) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(content: Text(courseBuilderError(lastError.code))),
            );
        }
      }
    },
    builder: (context, state) => switch (state) {
      CourseBuilderLoading() => const Center(
        child: AppSkeleton(),
      ),
      CourseBuilderFailed(:final error) => ErrorRetry(
        title: courseBuilderError(error.code),
        message: '',
        onRetry: () =>
            unawaited(context.read<CourseBuilderCubit>().load(courseId)),
      ),
      CourseBuilderLoaded(tree: null) => const EmptyState(
        title: 'No courses yet.',
        message: '',
        illustration: AppIllustrationName.builderEmpty,
      ),
      CourseBuilderLoaded() => _BuilderBody(loaded: state, courseId: courseId),
    },
  );
}

class _BuilderBody extends StatelessWidget {
  const _BuilderBody({required this.loaded, required this.courseId});
  final CourseBuilderLoaded loaded;
  final String? courseId;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.all(AppSpace.s6),
        child: Text(
          'Course builder',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
      ),
      const Divider(height: AppStroke.thin),
      if (loaded.busyId != null)
        const LinearProgressIndicator(minHeight: AppSize.progressThickness),
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpace.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: AppSpace.s4,
            children: [
              DropdownButtonFormField<String>(
                key: ValueKey(courseId ?? loaded.tree!.courseId),
                initialValue: courseId ?? loaded.tree!.courseId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Course'),
                items: [
                  for (final course in loaded.courses)
                    DropdownMenuItem(
                      value: course.id,
                      child: Text(
                        course.title,
                        textDirection: TextDirection.ltr,
                      ),
                    ),
                ],
                onChanged: loaded.busyId != null
                    ? null
                    : (id) {
                        if (id != null && id != courseId) {
                          context.go(
                            '/teacher/courses/${Uri.encodeComponent(id)}',
                          );
                        }
                      },
              ),
              const Text(
                'Drag a row by its handle to reorder. '
                'Students follow this order on their path.',
              ),
              BuilderTree(loaded: loaded),
              TextButton.icon(
                onPressed: loaded.busyId != null
                    ? null
                    : () => unawaited(
                        context.read<CourseBuilderCubit>().load(courseId),
                      ),
                icon: const Icon(AppIcons.retry),
                label: const Text('Reload'),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}
