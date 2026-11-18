import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:sat_east_client/core/di/injection.dart';
import 'package:sat_east_client/core/router/app_router.dart';
import 'package:sat_east_client/core/router/route_refresh_listener.dart';
import 'package:sat_east_client/core/theme/app_colors.dart';
import 'package:sat_east_client/core/theme/app_icons.dart';
import 'package:sat_east_client/core/theme/app_tokens.dart';
import 'package:sat_east_client/features/mock/domain/entities/mock_entities.dart';
import 'package:sat_east_client/features/mock/presentation/cubit/mock_hub_cubit.dart';
import 'package:sat_east_client/features/mock/presentation/cubit/mock_hub_state.dart';
import 'package:sat_east_client/features/mock/presentation/mock_copy.dart';
import 'package:sat_east_client/features/mock/presentation/widgets/mock_form_card.dart';
import 'package:sat_east_client/features/mock/presentation/widgets/mock_page_column.dart';
import 'package:sat_east_client/shared/widgets/app_banner.dart';
import 'package:sat_east_client/shared/widgets/app_skeleton.dart';
import 'package:sat_east_client/shared/widgets/empty_state.dart';
import 'package:sat_east_client/shared/widgets/error_retry.dart';

class MockHubScreen extends StatelessWidget {
  const MockHubScreen({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider<MockHubCubit>(
    create: (_) {
      final cubit = getIt<MockHubCubit>();
      unawaited(cubit.load());
      return cubit;
    },
    child: const MockHubView(),
  );
}

/// Reads [MockHubCubit] from context (testable with a fake repository).
class MockHubView extends StatelessWidget {
  const MockHubView({super.key});

  @override
  Widget build(BuildContext context) => RouteRefreshListener(
    location: AppRoutes.mockExams,
    refreshOnReselect: true,
    onRefresh: () => unawaited(context.read<MockHubCubit>().load()),
    child: BlocBuilder<MockHubCubit, MockHubState>(
      builder: (context, state) => switch (state) {
        MockHubLoading() => const MockPageColumn(
          children: [
            _Header(),
            AppSkeleton(label: 'Loading mock exams'),
          ],
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
        MockHubLoaded() => _Loaded(state: state),
      },
    ),
  );
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    spacing: AppSpace.s1,
    children: [
      Semantics(
        header: true,
        child: Text(
          MockCopy.hubTitle,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
      ),
      Text(
        MockCopy.hubIntro,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: context.appColors.inkSecondary,
        ),
      ),
    ],
  );
}

class _Loaded extends StatelessWidget {
  const _Loaded({required this.state});

  final MockHubLoaded state;

  /// An unfinished run is resumed before another form can start, and only the
  /// lowest available form starts (the server picks the same one).
  VoidCallback? _action(BuildContext context, MockHubForm form) {
    final active = state.hub.activeGroup;
    if (form.state == MockFormState.inProgress && active != null) {
      return () => context.go(AppRoutes.mockRun(active));
    }
    if (form.state == MockFormState.available &&
        active == null &&
        form == _firstAvailable) {
      return () => context.go(AppRoutes.mockStart);
    }
    return null;
  }

  MockHubForm? get _firstAvailable {
    for (final form in state.hub.forms) {
      if (form.state == MockFormState.available) return form;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final error = state.lastError;
    final forms = state.hub.forms;
    return MockPageColumn(
      children: [
        const _Header(),
        if (error != null)
          AppBanner(
            message: MockCopy.errorBody(error.code),
            kind: AppBannerKind.error,
          ),
        if (forms.isEmpty)
          const EmptyState(
            title: MockCopy.noFormsTitle,
            message: MockCopy.noFormsMessage,
            icon: AppIcons.mockExams,
          )
        else
          for (final form in forms)
            MockFormCard(
              form: form,
              passedTopics: state.hub.passedTopics,
              onAction: _action(context, form),
            ),
      ],
    );
  }
}
