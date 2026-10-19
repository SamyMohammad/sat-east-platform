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
import 'package:sat_east_client/core/theme/booklet_tokens.dart';
import 'package:sat_east_client/features/course_map/domain/entities/course_map.dart';
import 'package:sat_east_client/features/course_map/presentation/course_map_copy.dart';
import 'package:sat_east_client/features/course_map/presentation/cubit/course_map_cubit.dart';
import 'package:sat_east_client/features/course_map/presentation/cubit/course_map_state.dart';
import 'package:sat_east_client/features/course_map/presentation/widgets/continue_card.dart';
import 'package:sat_east_client/features/course_map/presentation/widgets/topic_row.dart';
import 'package:sat_east_client/shared/widgets/booklet_skeleton.dart';
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
        CourseMapLoading() => const _Padded(child: BookletSkeleton()),
        CourseMapLoaded(:final map) => _Loaded(map: map),
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
      constraints: const BoxConstraints(maxWidth: BookletSize.readingColumn),
      child: Padding(
        padding: const EdgeInsets.all(BookletSpace.s4),
        child: child,
      ),
    ),
  );
}

class _Loaded extends StatelessWidget {
  const _Loaded({required this.map});

  final CourseMap map;

  @override
  Widget build(BuildContext context) {
    if (map.units.isEmpty) {
      return const EmptyState(
        title: CourseMapCopy.emptyTitle,
        message: CourseMapCopy.emptyBody,
      );
    }
    final theme = Theme.of(context);
    final continueTopic = map.continueTopic;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: BookletSize.readingColumn),
        child: ListView(
          padding: const EdgeInsets.all(BookletSpace.s4),
          children: [
            Text(
              map.title,
              style: theme.textTheme.headlineSmall,
              textDirection: detectTextDirection(map.title),
            ),
            const SizedBox(height: BookletSpace.s4),
            if (continueTopic != null) ...[
              ContinueCard(topic: continueTopic),
              const SizedBox(height: BookletSpace.s6),
            ],
            for (final unit in map.units) ...[
              if (unit.title case final unitTitle?)
                Padding(
                  padding: const EdgeInsets.only(
                    top: BookletSpace.s4,
                    bottom: BookletSpace.s2,
                  ),
                  child: Semantics(
                    header: true,
                    child: Text(
                      unitTitle,
                      style: theme.textTheme.titleMedium,
                      textDirection: detectTextDirection(unitTitle),
                    ),
                  ),
                ),
              for (final topic in unit.topics) TopicRow(topic: topic),
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
