import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:sat_east_client/core/di/injection.dart';
import 'package:sat_east_client/core/router/app_router.dart';
import 'package:sat_east_client/core/theme/app_tokens.dart';
import 'package:sat_east_client/features/teacher/mock/presentation/cubit/mock_overview_cubit.dart';
import 'package:sat_east_client/features/teacher/mock/presentation/cubit/mock_overview_state.dart';
import 'package:sat_east_client/features/teacher/mock/presentation/mock_copy.dart';
import 'package:sat_east_client/features/teacher/mock/presentation/widgets/mock_assemble_dialog.dart';
import 'package:sat_east_client/features/teacher/mock/presentation/widgets/mock_forms_list.dart';
import 'package:sat_east_client/features/teacher/mock/presentation/widgets/mock_readiness_card.dart';
import 'package:sat_east_client/shared/widgets/app_banner.dart';
import 'package:sat_east_client/shared/widgets/app_skeleton.dart';
import 'package:sat_east_client/shared/widgets/empty_state.dart';
import 'package:sat_east_client/shared/widgets/error_retry.dart';
import 'package:sat_east_client/shared/widgets/loading_button.dart';

class MockOverviewScreen extends StatelessWidget {
  const MockOverviewScreen({super.key});
  @override
  Widget build(BuildContext context) => BlocProvider<MockOverviewCubit>(
    create: (_) {
      final cubit = getIt<MockOverviewCubit>();
      unawaited(cubit.load());
      return cubit;
    },
    child: const MockOverviewView(),
  );
}

class MockOverviewView extends StatelessWidget {
  const MockOverviewView({super.key});

  @override
  Widget build(BuildContext context) =>
      BlocConsumer<MockOverviewCubit, MockOverviewState>(
        listenWhen: (previous, current) =>
            current is MockOverviewLoaded &&
            current.lastError != null &&
            (previous is! MockOverviewLoaded ||
                previous.lastError != current.lastError),
        listener: (context, state) {
          if (state is MockOverviewLoaded && state.lastError != null) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(content: Text(mockErrorCopy(state.lastError!.code))),
              );
          }
        },
        builder: (context, state) => switch (state) {
          MockOverviewLoading() => const Center(child: AppSkeleton()),
          MockOverviewNoCourse() => const EmptyState(
            title: mockNoCourseTitle,
            message: mockNoCourseMessage,
          ),
          MockOverviewFailed(:final error) => ErrorRetry(
            title: mockErrorCopy(error.code),
            message: '',
            onRetry: () => unawaited(context.read<MockOverviewCubit>().retry()),
          ),
          MockOverviewLoaded() => _Body(loaded: state),
        },
      );
}

class _Body extends StatelessWidget {
  const _Body({required this.loaded});
  final MockOverviewLoaded loaded;

  Future<void> _assemble(BuildContext context) async {
    final cubit = context.read<MockOverviewCubit>();
    final router = GoRouter.of(context);
    final setNo = await showMockAssembleDialog(
      context,
      existingSets: [for (final f in loaded.overview.forms) f.setNo],
    );
    if (setNo == null || cubit.isClosed) return;
    final assembled = await cubit.assemble(setNo);
    if (assembled != null && context.mounted) {
      router.go(AppRoutes.teacherMockForm(assembled.setNo, assembled.formNo));
    }
  }

  @override
  Widget build(BuildContext context) {
    final overview = loaded.overview;
    final shortage = loaded.lastShortage;
    return SizedBox.expand(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpace.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpace.s4,
          children: [
            Text(
              mockOverviewTitle,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: LoadingButton(
                label: mockAssembleLabel,
                isLoading: loaded.busy,
                onPressed: () => unawaited(_assemble(context)),
              ),
            ),
            if (shortage != null)
              const AppBanner(
                message: mockShortageBanner,
                kind: AppBannerKind.warning,
              ),
            MockReadinessCard(
              missing: shortage?.missing ?? overview.missing,
              noDomain: shortage?.noDomain ?? overview.noDomain,
              needPerForm: overview.needPerForm,
            ),
            Text(
              mockFormsTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            MockFormsList(forms: overview.forms),
          ],
        ),
      ),
    );
  }
}
