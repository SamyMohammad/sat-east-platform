import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:sat_east_client/core/di/injection.dart';
import 'package:sat_east_client/core/router/app_router.dart';
import 'package:sat_east_client/core/theme/booklet_tokens.dart';
import 'package:sat_east_client/features/attempt_review/presentation/attempt_review_copy.dart';
import 'package:sat_east_client/features/attempt_review/presentation/cubit/attempt_review_cubit.dart';
import 'package:sat_east_client/features/attempt_review/presentation/cubit/attempt_review_state.dart';
import 'package:sat_east_client/features/attempt_review/presentation/widgets/review_question_card.dart';
import 'package:sat_east_client/shared/widgets/app_skeleton.dart';
import 'package:sat_east_client/shared/widgets/empty_state.dart';

class AttemptReviewScreen extends StatelessWidget {
  const AttemptReviewScreen({required this.attemptId, super.key});
  final String attemptId;
  @override
  Widget build(BuildContext context) => BlocProvider(
    key: ValueKey(attemptId),
    create: (_) {
      final cubit = getIt<AttemptReviewCubit>();
      unawaited(cubit.load(attemptId));
      return cubit;
    },
    child: AttemptReviewView(attemptId: attemptId),
  );
}

class AttemptReviewView extends StatelessWidget {
  const AttemptReviewView({required this.attemptId, super.key});
  final String attemptId;
  @override
  Widget build(BuildContext context) => SafeArea(
    child: Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: BookletSize.readingColumn),
        child: BlocBuilder<AttemptReviewCubit, AttemptReviewState>(
          builder: (context, state) => switch (state) {
            AttemptReviewLoading() => const AppSkeleton(),
            AttemptReviewFailed(:final error) => EmptyState(
              title: AttemptReviewCopy.title,
              message: AttemptReviewCopy.errorBody(error.code),
              actionLabel: AttemptReviewCopy.retry,
              onAction: () =>
                  unawaited(context.read<AttemptReviewCubit>().load(attemptId)),
            ),
            AttemptReviewLoaded(:final review) => ListView(
              padding: const EdgeInsets.all(BookletSpace.s4),
              children: [
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton(
                    onPressed: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go(AppRoutes.courses);
                      }
                    },
                    child: const Text(AttemptReviewCopy.back),
                  ),
                ),
                Text(
                  AttemptReviewCopy.title,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: BookletSpace.s4),
                Text(
                  AttemptReviewCopy.score(
                    review.scoreRaw,
                    review.scoreTotal,
                    review.scorePct,
                  ),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (!review.keysVisible)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: BookletSpace.s3),
                    child: Text(AttemptReviewCopy.hidden),
                  ),
                if (review.questions.isEmpty)
                  const Text(AttemptReviewCopy.empty),
                for (var i = 0; i < review.questions.length; i++)
                  ReviewQuestionCard(
                    question: review.questions[i],
                    index: i,
                    keysVisible: review.keysVisible,
                  ),
              ],
            ),
          },
        ),
      ),
    ),
  );
}
