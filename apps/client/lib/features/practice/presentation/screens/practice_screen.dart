import 'dart:async';

import 'package:flutter/material.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:sat_east_client/core/di/injection.dart';
import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/core/presentation/learning_copy.dart';
import 'package:sat_east_client/core/router/app_router.dart';
import 'package:sat_east_client/core/theme/booklet_tokens.dart';
import 'package:sat_east_client/features/practice/presentation/cubit/practice_cubit.dart';
import 'package:sat_east_client/features/practice/presentation/cubit/practice_state.dart';
import 'package:sat_east_client/features/practice/presentation/practice_copy.dart';
import 'package:sat_east_client/features/practice/presentation/widgets/practice_question.dart';
import 'package:sat_east_client/features/practice/presentation/widgets/practice_summary.dart';
import 'package:sat_east_client/shared/widgets/app_skeleton.dart';
import 'package:sat_east_client/shared/widgets/empty_state.dart';
import 'package:sat_east_client/shared/widgets/error_retry.dart';

class PracticeScreen extends StatelessWidget {
  const PracticeScreen({required this.topicId, super.key, this.title});

  final String topicId;
  final String? title;

  @override
  Widget build(BuildContext context) => BlocProvider(
    key: ValueKey(topicId),
    create: (_) {
      final cubit = getIt<PracticeCubit>();
      unawaited(cubit.start(topicId));
      return cubit;
    },
    child: PracticeView(topicId: topicId, title: title),
  );
}

class PracticeView extends StatelessWidget {
  const PracticeView({required this.topicId, super.key, this.title});

  final String topicId;
  final String? title;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: BlocBuilder<PracticeCubit, PracticeState>(
      builder: (context, state) => switch (state) {
        PracticeLoading() => const _StatusContent(child: AppSkeleton()),
        PracticeFailed(:final error) => _StatusContent(
          child: _Failed(topicId: topicId, error: error),
        ),
        final PracticeInProgress progress => PracticeQuestionView(
          title: title ?? PracticeCopy.title,
          progress: progress,
        ),
        PracticeSummary(:final correctFirstTry, :final total) => _StatusContent(
          child: PracticeSummaryView(
            correctFirstTry: correctFirstTry,
            total: total,
            onPracticeMore: () =>
                unawaited(context.read<PracticeCubit>().practiceMore()),
            onBack: () => context.go(AppRoutes.courses),
            onBackToTopic: () => context.go(AppRoutes.topic(topicId)),
          ),
        ),
      },
    ),
  );
}

class _StatusContent extends StatelessWidget {
  const _StatusContent({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: BookletSize.readingColumn),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(BookletSpace.s4),
        child: child,
      ),
    ),
  );
}

class _Failed extends StatelessWidget {
  const _Failed({required this.topicId, required this.error});

  final String topicId;
  final AppError error;

  @override
  Widget build(BuildContext context) {
    void back() => context.go(AppRoutes.courses);
    return switch (error.code) {
      ErrorCodes.topicLocked => EmptyState(
        title: PracticeCopy.title,
        message: PracticeCopy.lockedBody,
        actionLabel: PracticeCopy.backButton,
        onAction: back,
      ),
      ErrorCodes.poolExhausted => EmptyState(
        title: PracticeCopy.title,
        message: PracticeCopy.emptyBody,
        actionLabel: PracticeCopy.backButton,
        onAction: back,
      ),
      ErrorCodes.notEnrolled => EmptyState(
        title: LearningCopy.notEnrolledTitle,
        message: LearningCopy.notEnrolledBody,
        actionLabel: PracticeCopy.backButton,
        onAction: back,
      ),
      ErrorCodes.accessExpired => EmptyState(
        title: LearningCopy.expiredTitle,
        message: LearningCopy.expiredBody,
        actionLabel: PracticeCopy.backButton,
        onAction: back,
      ),
      final code => ErrorRetry(
        title: PracticeCopy.errorTitle,
        message: PracticeCopy.errorBody(code),
        onRetry: () => unawaited(context.read<PracticeCubit>().start(topicId)),
        secondaryLabel: PracticeCopy.backButton,
        onSecondary: back,
      ),
    };
  }
}
