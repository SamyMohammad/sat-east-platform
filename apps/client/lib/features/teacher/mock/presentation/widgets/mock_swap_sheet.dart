import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sat_east_client/core/theme/app_colors.dart';
import 'package:sat_east_client/core/theme/app_tokens.dart';
import 'package:sat_east_client/features/teacher/mock/domain/entities/mock_entities.dart';
import 'package:sat_east_client/features/teacher/mock/presentation/cubit/mock_form_cubit.dart';
import 'package:sat_east_client/features/teacher/mock/presentation/cubit/mock_form_state.dart';
import 'package:sat_east_client/features/teacher/mock/presentation/mock_copy.dart';
import 'package:sat_east_client/features/teacher/mock/presentation/widgets/mock_confirm_dialog.dart';
import 'package:sat_east_client/shared/widgets/app_overlays.dart';
import 'package:sat_east_client/shared/widgets/app_skeleton.dart';

/// Opens the candidate sheet for the slot the cubit is swapping. The sheet
/// closes itself when the cubit clears `swappingId` (swapped, failed or the
/// form changed under us).
Future<void> showMockSwapSheet(BuildContext context, MockFormCubit cubit) =>
    showAppSheet<void>(
      context: context,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: const _SwapSheetBody(),
      ),
    ).whenComplete(cubit.closeSwap);

class _SwapSheetBody extends StatelessWidget {
  const _SwapSheetBody();

  @override
  Widget build(BuildContext context) =>
      BlocConsumer<MockFormCubit, MockFormState>(
        listenWhen: (previous, current) =>
            previous is MockFormLoaded &&
            previous.swappingId != null &&
            (current is! MockFormLoaded || current.swappingId == null),
        listener: (context, state) => Navigator.of(context).maybePop(),
        builder: (context, state) {
          if (state is! MockFormLoaded || state.swappingId == null) {
            return const SizedBox.shrink();
          }
          final theme = Theme.of(context);
          final candidates = state.candidates;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: AppSpace.s2,
            children: [
              Text(mockSwapTitle, style: theme.textTheme.titleLarge),
              if (state.lastError case final error?)
                Text(
                  mockErrorCopy(error.code),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: context.appColors.incorrect,
                  ),
                ),
              if (candidates == null)
                const Padding(
                  padding: EdgeInsets.all(AppSpace.s4),
                  child: Center(child: AppSkeleton()),
                )
              else if (candidates.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(AppSpace.s4),
                  child: Text(
                    mockNoCandidates,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: context.appColors.inkSecondary,
                    ),
                  ),
                )
              else
                for (final candidate in candidates)
                  _CandidateTile(
                    candidate: candidate,
                    oldRef: _currentRef(state),
                    busy: state.busy,
                  ),
            ],
          );
        },
      );

  String _currentRef(MockFormLoaded state) {
    for (final module in state.form.modules) {
      for (final slot in module.slots) {
        if (slot.questionId == state.swappingId) {
          return slot.externalRef ?? mockNoReference;
        }
      }
    }
    return mockNoReference;
  }
}

class _CandidateTile extends StatelessWidget {
  const _CandidateTile({
    required this.candidate,
    required this.oldRef,
    required this.busy,
  });
  final MockCandidate candidate;
  final String oldRef;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final ref = candidate.externalRef ?? mockNoReference;
    return ListTile(
      enabled: !busy,
      title: Text(ref),
      subtitle: Text(
        mockStemLine(candidate.stemMd),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: () => unawaited(_swap(context, ref)),
    );
  }

  Future<void> _swap(BuildContext context, String ref) async {
    final cubit = context.read<MockFormCubit>();
    final confirmed = await confirmMockAction(
      context,
      title: mockSwapConfirmTitle,
      body: mockSwapConfirmBody(oldRef, ref),
      actionLabel: mockSwapConfirmLabel,
    );
    if (confirmed) await cubit.swap(candidate.id);
  }
}
