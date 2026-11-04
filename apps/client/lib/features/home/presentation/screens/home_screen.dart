import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sat_east_client/core/di/injection.dart';
import 'package:sat_east_client/core/router/app_router.dart';
import 'package:sat_east_client/core/router/route_refresh_listener.dart';
import 'package:sat_east_client/core/theme/app_tokens.dart';
import 'package:sat_east_client/features/home/domain/entities/home_summary.dart';
import 'package:sat_east_client/features/home/presentation/cubit/home_cubit.dart';
import 'package:sat_east_client/features/home/presentation/cubit/home_state.dart';
import 'package:sat_east_client/features/home/presentation/home_copy.dart';
import 'package:sat_east_client/features/home/presentation/widgets/home_continue_card.dart';
import 'package:sat_east_client/features/home/presentation/widgets/home_course_card.dart';
import 'package:sat_east_client/features/home/presentation/widgets/home_expiry_banner.dart';
import 'package:sat_east_client/features/home/presentation/widgets/home_greeting.dart';
import 'package:sat_east_client/features/home/presentation/widgets/home_message_card.dart';
import 'package:sat_east_client/shared/widgets/app_skeleton.dart';
import 'package:sat_east_client/shared/widgets/error_retry.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) {
      final cubit = getIt<HomeCubit>();
      unawaited(cubit.load());
      return cubit;
    },
    child: const HomeView(),
  );
}

class HomeView extends StatelessWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) => RouteRefreshListener(
    location: AppRoutes.home,
    refreshOnReselect: true,
    onRefresh: () => unawaited(context.read<HomeCubit>().retry()),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSize.readingColumn),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpace.s4),
            child: BlocBuilder<HomeCubit, HomeState>(
              builder: (context, state) => switch (state) {
                HomeLoading() => const AppSkeleton(),
                HomeLoaded(:final summary) => _Loaded(summary: summary),
                HomeFailed(:final error) => ErrorRetry(
                  title: HomeCopy.errorTitle,
                  message: HomeCopy.errorBody(error.code),
                  onRetry: () => unawaited(context.read<HomeCubit>().retry()),
                ),
              },
            ),
          ),
        ),
      ),
    ),
  );
}

class _Loaded extends StatelessWidget {
  const _Loaded({required this.summary});
  final HomeSummary summary;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: AppSpace.s6,
    children: switch (summary) {
      final HomeReady ready => [
        HomeGreeting(
          firstName: ready.firstName,
          firstRun: ready.firstRun,
          courseTitle: ready.courseTitle,
          unitTitle: ready.unitTitle,
        ),
        if (ready.expiry case final warning?)
          HomeExpiryBanner(courseTitle: ready.courseTitle, warning: warning),
        HomeContinueCard(summary: ready),
        HomeCourseCard(summary: ready),
      ],
      HomeFinished() || HomeExpired() || HomeNotEnrolled() => [
        HomeGreeting(firstName: summary.firstName),
        HomeMessageCard(summary: summary),
      ],
    },
  );
}
