import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:sat_east_client/core/di/injection.dart';
import 'package:sat_east_client/core/text/text_direction.dart';
import 'package:sat_east_client/core/theme/app_icons.dart';
import 'package:sat_east_client/core/theme/booklet_tokens.dart';
import 'package:sat_east_client/features/teacher/course_builder/presentation/course_builder_copy.dart';
import 'package:sat_east_client/features/teacher/course_builder/presentation/cubit/course_builder_cubit.dart';
import 'package:sat_east_client/features/teacher/course_builder/presentation/cubit/course_builder_state.dart';
import 'package:sat_east_client/features/teacher/course_builder/presentation/widgets/builder_tree.dart';

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
        child: CircularProgressIndicator(),
      ),
      CourseBuilderFailed(:final error) => Center(
        child: Padding(
          padding: const EdgeInsets.all(BookletSpace.s6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(courseBuilderError(error.code)),
              TextButton(
                onPressed: () => unawaited(
                  context.read<CourseBuilderCubit>().load(courseId),
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      CourseBuilderLoaded(tree: null) => const Center(
        child: Text('No courses yet.'),
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
        padding: const EdgeInsets.all(BookletSpace.s6),
        child: Text(
          'Course builder',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
      ),
      const Divider(height: BookletStroke.thin),
      if (loaded.busyId != null)
        const LinearProgressIndicator(minHeight: BookletSize.progressThickness),
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(BookletSpace.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: BookletSpace.s4,
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
                        textDirection: detectTextDirection(course.title),
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
