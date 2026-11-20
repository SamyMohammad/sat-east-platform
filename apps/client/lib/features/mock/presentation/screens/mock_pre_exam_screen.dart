import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:sat_east_client/core/di/injection.dart';
import 'package:sat_east_client/core/router/app_router.dart';
import 'package:sat_east_client/core/theme/app_colors.dart';
import 'package:sat_east_client/core/theme/app_icons.dart';
import 'package:sat_east_client/core/theme/app_tokens.dart';
import 'package:sat_east_client/features/mock/presentation/cubit/mock_hub_cubit.dart';
import 'package:sat_east_client/features/mock/presentation/cubit/mock_hub_state.dart';
import 'package:sat_east_client/features/mock/presentation/mock_copy.dart';
import 'package:sat_east_client/features/mock/presentation/widgets/mock_page_column.dart';
import 'package:sat_east_client/shared/widgets/app_banner.dart';
import 'package:sat_east_client/shared/widgets/app_skeleton.dart';
import 'package:sat_east_client/shared/widgets/empty_state.dart';
import 'package:sat_east_client/shared/widgets/error_retry.dart';
import 'package:sat_east_client/shared/widgets/loading_button.dart';

/// Opens cold (reload, deep link): it loads the course itself, so the route
/// carries no parameters.
class MockPreExamScreen extends StatelessWidget {
  const MockPreExamScreen({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider<MockHubCubit>(
    create: (_) {
      final cubit = getIt<MockHubCubit>();
      unawaited(cubit.load());
      return cubit;
    },
    child: const MockPreExamView(),
  );
}

/// Reads [MockHubCubit] from context (testable with a fake repository).
class MockPreExamView extends StatelessWidget {
  const MockPreExamView({super.key});

  Future<void> _start(BuildContext context) async {
    final cubit = context.read<MockHubCubit>();
    final router = GoRouter.of(context);
    final stage = await cubit.start();
    if (stage == null || cubit.isClosed || !context.mounted) return;
    router.go(AppRoutes.mockRun(stage.groupId));
  }

  @override
  Widget build(BuildContext context) => BlocBuilder<MockHubCubit, MockHubState>(
    builder: (context, state) => switch (state) {
      MockHubLoading() => const MockPageColumn(
        children: [AppSkeleton(label: 'Loading')],
      ),
      MockHubNoCourse() => const EmptyState(
        title: MockCopy.noCourseTitle,
        message: MockCopy.noCourseMessage,
        icon: AppIcons.mockExams,
      ),
      MockHubFailed(:final error) => ErrorRetry(
        title: MockCopy.errorTitle(error.code),
        message: MockCopy.errorBody(error.code),
        onRetry: () => unawaited(context.read<MockHubCubit>().retry()),
      ),
      MockHubLoaded() => _Loaded(
        state: state,
        onStart: () => unawaited(_start(context)),
      ),
    },
  );
}

class _Loaded extends StatelessWidget {
  const _Loaded({required this.state, required this.onStart});

  final MockHubLoaded state;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final error = state.lastError;
    final phone =
        AppLayout.forWidth(MediaQuery.sizeOf(context).width) ==
        AppLayout.compact;
    return MockPageColumn(
      children: [
        Semantics(
          header: true,
          child: Text(
            MockCopy.preExamTitle,
            style: theme.textTheme.headlineSmall,
          ),
        ),
        if (phone)
          const AppBanner(
            message: MockCopy.phoneBanner,
            kind: AppBannerKind.warning,
          ),
        if (error != null)
          AppBanner(
            message: MockCopy.errorBody(error.code),
            kind: AppBannerKind.error,
          ),
        Text(
          MockCopy.preExamIntro,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: context.appColors.inkSecondary,
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.s4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: AppSpace.s3,
              children: [
                for (final rule in MockCopy.preExamRules)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: AppSpace.s3,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: AppSpace.s1),
                        child: Icon(
                          AppIcons.completed,
                          size: AppSize.iconStatus,
                        ),
                      ),
                      Expanded(
                        child: Text(rule, style: theme.textTheme.bodyMedium),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: LoadingButton(
            label: MockCopy.startModule1,
            isLoading: state.busy,
            onPressed: onStart,
          ),
        ),
      ],
    );
  }
}
