import 'dart:async';

import 'package:flutter/material.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:sat_east_client/core/di/injection.dart';
import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/core/router/app_router.dart';
import 'package:sat_east_client/core/router/route_refresh_listener.dart';
import 'package:sat_east_client/core/text/text_direction.dart';
import 'package:sat_east_client/core/theme/app_hues.dart';
import 'package:sat_east_client/core/theme/app_tokens.dart';
import 'package:sat_east_client/features/course_map/domain/entities/course_map.dart';
import 'package:sat_east_client/features/course_map/presentation/course_map_copy.dart';
import 'package:sat_east_client/features/course_map/presentation/cubit/course_map_cubit.dart';
import 'package:sat_east_client/features/course_map/presentation/cubit/course_map_state.dart';
import 'package:sat_east_client/features/course_map/presentation/widgets/continue_card.dart';
import 'package:sat_east_client/features/course_map/presentation/widgets/topic_row.dart';
import 'package:sat_east_client/shared/widgets/app_illustration.dart';
import 'package:sat_east_client/shared/widgets/app_skeleton.dart';
import 'package:sat_east_client/shared/widgets/empty_state.dart';
import 'package:sat_east_client/shared/widgets/error_retry.dart';

class CourseMapScreen extends StatelessWidget {
  const CourseMapScreen({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) {
      final cubit = getIt<CourseMapCubit>();
      unawaited(cubit.load());
      return cubit;
    },
    child: const CourseMapView(),
  );
}

/// Reads [CourseMapCubit] from context (testable with a mock cubit).
class CourseMapView extends StatelessWidget {
  const CourseMapView({super.key});

  @override
  Widget build(BuildContext context) => RouteRefreshListener(
    location: AppRoutes.courses,
    refreshOnReselect: true,
    onRefresh: () => unawaited(context.read<CourseMapCubit>().load()),
    child: BlocBuilder<CourseMapCubit, CourseMapState>(
      builder: (context, state) => switch (state) {
        CourseMapLoading() => const _Padded(child: AppSkeleton()),
        CourseMapLoaded(:final map, :final justUnlocked) => _Loaded(
          map: map,
          justUnlocked: justUnlocked,
        ),
        CourseMapFailed(:final error) => _Failed(error: error),
      },
    ),
  );
}

class _Padded extends StatelessWidget {
  const _Padded({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: AppSize.readingColumn),
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.s4),
        child: child,
      ),
    ),
  );
}

class _Loaded extends StatelessWidget {
  const _Loaded({required this.map, required this.justUnlocked});

  final CourseMap map;
  final Set<String> justUnlocked;

  @override
  Widget build(BuildContext context) {
    if (map.units.isEmpty) {
      return const EmptyState(
        illustration: AppIllustrationName.emptyCourses,
        title: CourseMapCopy.emptyTitle,
        message: CourseMapCopy.emptyBody,
      );
    }
    final theme = Theme.of(context);
    final continueTopic = map.continueTopic;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSize.readingColumn),
        child: ListView(
          padding: const EdgeInsets.all(AppSpace.s4),
          children: [
            Text(
              map.title,
              style: theme.textTheme.headlineSmall,
              textDirection: detectTextDirection(map.title),
            ),
            const SizedBox(height: AppSpace.s4),
            if (continueTopic != null) ...[
              ContinueCard(topic: continueTopic),
              const SizedBox(height: AppSpace.s6),
            ],
            for (final (unitIndex, unit) in map.units.indexed) ...[
              if (unit.title case final unitTitle?)
                Padding(
                  padding: const EdgeInsets.only(
                    top: AppSpace.s4,
                    bottom: AppSpace.s2,
                  ),
                  child: Semantics(
                    header: true,
                    child: Container(
                      padding: const EdgeInsets.all(AppSpace.s4),
                      decoration: BoxDecoration(
                        color: SubjectHue.forIndex(
                          unitIndex,
                        ).wash(theme.brightness),
                        borderRadius: BorderRadius.circular(AppRadius.card),
                      ),
                      child: Text(
                        unitTitle,
                        style: theme.textTheme.titleMedium,
                        textDirection: detectTextDirection(unitTitle),
                      ),
                    ),
                  ),
                ),
              for (final (topicIndex, topic) in unit.topics.indexed)
                TopicRow(
                  key: ValueKey(topic.id),
                  topic: topic,
                  hue: SubjectHue.forIndex(unitIndex),
                  justUnlocked: justUnlocked.contains(topic.id),
                  connectFromPrevious: topicIndex > 0
                      ? unit.topics[topicIndex - 1].status ==
                            TopicStatus.completed
                      : unitIndex > 0 &&
                            map.units[unitIndex - 1].topics.isNotEmpty &&
                            map.units[unitIndex - 1].topics.last.status ==
                                TopicStatus.completed,
                  onUnlockComplete: () {
                    final cubit = context.read<CourseMapCubit>();
                    final current = cubit.state;
                    if (current is CourseMapLoaded &&
                        identical(current.justUnlocked, justUnlocked)) {
                      cubit.acknowledgeUnlock();
                    }
                  },
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Failed extends StatelessWidget {
  const _Failed({required this.error});

  final AppError error;

  @override
  Widget build(BuildContext context) => switch (error.code) {
    ErrorCodes.notEnrolled => EmptyState(
      title: CourseMapCopy.notEnrolledTitle,
      message: CourseMapCopy.notEnrolledBody,
      actionLabel: 'Enter activation code',
      onAction: () => context.go(AppRoutes.activate),
      secondaryActionLabel: 'Browse courses',
      onSecondaryAction: () => context.go(AppRoutes.catalogue),
    ),
    ErrorCodes.accessExpired => const EmptyState(
      title: CourseMapCopy.expiredTitle,
      message: CourseMapCopy.expiredBody,
    ),
    final code => ErrorRetry(
      title: CourseMapCopy.errorTitle,
      message: CourseMapCopy.errorBody(code),
      onRetry: () => context.read<CourseMapCubit>().retry(),
    ),
  };
}
