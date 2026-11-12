import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:sat_east_client/core/di/injection.dart';
import 'package:sat_east_client/core/router/app_router.dart';
import 'package:sat_east_client/core/theme/app_colors.dart';
import 'package:sat_east_client/core/theme/app_icons.dart';
import 'package:sat_east_client/core/theme/app_tokens.dart';
import 'package:sat_east_client/features/teacher/mock/presentation/cubit/mock_form_cubit.dart';
import 'package:sat_east_client/features/teacher/mock/presentation/cubit/mock_form_state.dart';
import 'package:sat_east_client/features/teacher/mock/presentation/mock_copy.dart';
import 'package:sat_east_client/features/teacher/mock/presentation/widgets/mock_confirm_dialog.dart';
import 'package:sat_east_client/features/teacher/mock/presentation/widgets/mock_module_section.dart';
import 'package:sat_east_client/features/teacher/mock/presentation/widgets/mock_preview_panel.dart';
import 'package:sat_east_client/features/teacher/mock/presentation/widgets/mock_swap_sheet.dart';
import 'package:sat_east_client/shared/widgets/app_banner.dart';
import 'package:sat_east_client/shared/widgets/app_chip.dart';
import 'package:sat_east_client/shared/widgets/app_overlays.dart';
import 'package:sat_east_client/shared/widgets/app_skeleton.dart';
import 'package:sat_east_client/shared/widgets/empty_state.dart';
import 'package:sat_east_client/shared/widgets/error_retry.dart';
import 'package:sat_east_client/shared/widgets/loading_button.dart';

/// Set and form numbers above this are treated as not found (no server call).
const _maxParam = 100000;

/// Route entry: parses the `:setNo/:formNo` path parameters. Anything that
/// is not a positive integer is the same "form not found" page as a form
/// that no longer exists.
class MockFormScreen extends StatelessWidget {
  const MockFormScreen({required this.setNo, required this.formNo, super.key});
  final String setNo;
  final String formNo;

  @override
  Widget build(BuildContext context) {
    final set = int.tryParse(setNo);
    final form = int.tryParse(formNo);
    if (set == null ||
        form == null ||
        set < 1 ||
        form < 1 ||
        set > _maxParam ||
        form > _maxParam) {
      return const MockFormMissingView();
    }
    return BlocProvider<MockFormCubit>(
      key: ValueKey('$set/$form'),
      create: (_) {
        final cubit = getIt<MockFormCubit>(param1: (setNo: set, formNo: form));
        unawaited(cubit.load());
        return cubit;
      },
      child: const MockFormView(),
    );
  }
}

class MockFormMissingView extends StatelessWidget {
  const MockFormMissingView({super.key});
  @override
  Widget build(BuildContext context) => EmptyState(
    title: mockFormMissingTitle,
    message: mockFormMissingMessage,
    icon: AppIcons.mockExams,
    actionLabel: mockBackToList,
    onAction: () => context.go(AppRoutes.teacherMockExams),
  );
}

class MockFormView extends StatelessWidget {
  const MockFormView({super.key});

  @override
  Widget build(BuildContext context) =>
      BlocConsumer<MockFormCubit, MockFormState>(
        listenWhen: (previous, current) =>
            current is MockFormLoaded &&
            current.lastError != null &&
            (previous is! MockFormLoaded ||
                previous.lastError != current.lastError),
        listener: (context, state) {
          if (state is MockFormLoaded && state.lastError != null) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(content: Text(mockErrorCopy(state.lastError!.code))),
              );
          }
        },
        buildWhen: (previous, current) =>
            current is! MockFormLoaded ||
            previous is! MockFormLoaded ||
            previous.form != current.form ||
            previous.stale != current.stale ||
            previous.busy != current.busy ||
            (previous.previewId == null) != (current.previewId == null) ||
            previous.previewId != current.previewId,
        builder: (context, state) => switch (state) {
          MockFormLoading() => const Center(child: AppSkeleton()),
          MockFormMissing() => const MockFormMissingView(),
          MockFormFailed(:final error) => ErrorRetry(
            title: mockErrorCopy(error.code),
            message: '',
            onRetry: () => unawaited(context.read<MockFormCubit>().load()),
          ),
          MockFormLoaded() => _Loaded(state: state),
        },
      );
}

class _Loaded extends StatelessWidget {
  const _Loaded({required this.state});
  final MockFormLoaded state;

  bool _wide(BuildContext context) =>
      AppLayout.forWidth(MediaQuery.sizeOf(context).width) ==
      AppLayout.expanded;

  void _preview(BuildContext context, String id) {
    final cubit = context.read<MockFormCubit>();
    unawaited(cubit.openPreview(id));
    if (_wide(context)) return;
    unawaited(
      showAppSheet<void>(
        context: context,
        builder: (_) => BlocProvider.value(
          value: cubit,
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.7,
            child: const MockPreviewSheetBody(),
          ),
        ),
      ).whenComplete(cubit.closePreview),
    );
  }

  void _swap(BuildContext context, String id) {
    final cubit = context.read<MockFormCubit>();
    if (!cubit.canOpenSwap) return;
    unawaited(cubit.openSwap(id));
    unawaited(showMockSwapSheet(context, cubit));
  }

  Future<void> _publish(BuildContext context) async {
    final cubit = context.read<MockFormCubit>();
    final form = state.form;
    final ok = await confirmMockAction(
      context,
      title: mockPublishTitle,
      body: mockPublishBody(form.setNo, form.formNo),
      actionLabel: mockPublishLabel,
    );
    if (ok) await cubit.publish();
  }

  Future<void> _delete(BuildContext context) async {
    final cubit = context.read<MockFormCubit>();
    final router = GoRouter.of(context);
    final form = state.form;
    final ok = await confirmMockAction(
      context,
      title: mockDeleteTitle,
      body: mockDeleteBody(form.setNo, form.formNo),
      actionLabel: mockDeleteLabel,
    );
    if (!ok) return;
    final gone = await cubit.delete();
    if (gone) router.go(AppRoutes.teacherMockExams);
  }

  @override
  Widget build(BuildContext context) {
    final form = state.form;
    final list = SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpace.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpace.s4,
        children: [
          _Header(
            state: state,
            onPublish: () => unawaited(_publish(context)),
            onDelete: () => unawaited(_delete(context)),
          ),
          if (state.stale.isNotEmpty)
            AppBanner(
              message: mockStaleBanner(state.stale.length),
              kind: AppBannerKind.warning,
            ),
          for (final module in form.modules)
            MockModuleSection(
              module: module,
              stale: state.stale,
              canSwap: state.isDraft,
              swapEnabled: !state.busy,
              selectedId: state.previewId,
              onPreview: (id) => _preview(context, id),
              onSwap: (id) => _swap(context, id),
            ),
        ],
      ),
    );
    if (_wide(context) && state.previewId != null) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: list),
          const VerticalDivider(width: AppStroke.thin),
          const SizedBox(
            width: 440,
            child: Padding(
              padding: EdgeInsets.all(AppSpace.s4),
              child: MockPreviewPanel(),
            ),
          ),
        ],
      );
    }
    return SizedBox.expand(child: list);
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.state,
    required this.onPublish,
    required this.onDelete,
  });
  final MockFormLoaded state;
  final VoidCallback onPublish;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final form = state.form;
    final publishedAt = form.publishedAt;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppSpace.s3,
      children: [
        TextButton.icon(
          onPressed: () => context.go(AppRoutes.teacherMockExams),
          icon: const Icon(AppIcons.back),
          label: const Text(mockAllForms),
        ),
        Wrap(
          spacing: AppSpace.s3,
          runSpacing: AppSpace.s2,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              mockFormTitle(form.setNo, form.formNo),
              style: theme.textTheme.headlineMedium,
            ),
            AppChip(label: mockStatusLabel(form.status)),
          ],
        ),
        if (publishedAt != null)
          Text(
            mockPublishedLine(publishedAt),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: context.appColors.inkSecondary,
            ),
          ),
        if (state.isDraft)
          Wrap(
            spacing: AppSpace.s3,
            runSpacing: AppSpace.s2,
            children: [
              LoadingButton(
                label: mockPublishLabel,
                isLoading: state.busy,
                onPressed: onPublish,
              ),
              LoadingButton(
                label: mockDeleteLabel,
                variant: AppButtonVariant.secondary,
                onPressed: state.busy ? null : onDelete,
              ),
            ],
          )
        else
          Text(mockPublishedReadOnly, style: theme.textTheme.bodyMedium),
      ],
    );
  }
}
