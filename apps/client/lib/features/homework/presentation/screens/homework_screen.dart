import 'dart:async';

import 'package:flutter/material.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:sat_east_client/core/di/injection.dart';
import 'package:sat_east_client/core/router/app_router.dart';
import 'package:sat_east_client/core/theme/app_tokens.dart';
import 'package:sat_east_client/features/homework/presentation/cubit/homework_cubit.dart';
import 'package:sat_east_client/features/homework/presentation/cubit/homework_state.dart';
import 'package:sat_east_client/features/homework/presentation/homework_copy.dart';
import 'package:sat_east_client/features/homework/presentation/widgets/homework_question.dart';
import 'package:sat_east_client/shared/widgets/app_banner.dart';
import 'package:sat_east_client/shared/widgets/app_skeleton.dart';
import 'package:sat_east_client/shared/widgets/error_retry.dart';

class HomeworkScreen extends StatelessWidget {
  const HomeworkScreen({required this.topicId, super.key});
  final String topicId;
  @override
  Widget build(BuildContext context) => BlocProvider(
    key: ValueKey(topicId),
    create: (_) {
      final cubit = getIt<HomeworkCubit>();
      unawaited(cubit.start(topicId));
      return cubit;
    },
    child: HomeworkView(topicId: topicId),
  );
}

class HomeworkView extends StatelessWidget {
  const HomeworkView({required this.topicId, super.key});
  final String topicId;
  @override
  Widget build(BuildContext context) =>
      BlocListener<HomeworkCubit, HomeworkState>(
        listener: (context, state) {
          if (state case HomeworkSubmitted(:final report)) {
            context.replace(AppRoutes.attemptReview(report.attemptId));
          }
        },
        child: SafeArea(
          child: BlocBuilder<HomeworkCubit, HomeworkState>(
            builder: (context, state) => switch (state) {
              HomeworkLoading() || HomeworkSubmitted() => const AppSkeleton(),
              HomeworkFailed(:final error) => SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpace.s4),
                child: ErrorRetry(
                  title: HomeworkCopy.title,
                  message: HomeworkCopy.errorBody(error.code),
                  onRetry: () =>
                      unawaited(context.read<HomeworkCubit>().start(topicId)),
                ),
              ),
              HomeworkRunning() => Column(
                children: [
                  if (state.submitting)
                    const Padding(
                      padding: EdgeInsets.all(AppSpace.s3),
                      child: AppBanner(message: HomeworkCopy.submitting),
                    ),
                  if (state.submitError case final error?)
                    Padding(
                      padding: const EdgeInsets.all(AppSpace.s3),
                      child: AppBanner(
                        message: HomeworkCopy.errorBody(error.code),
                        kind: AppBannerKind.error,
                      ),
                    ),
                  Expanded(
                    child: HomeworkQuestionView(topicId: topicId, state: state),
                  ),
                ],
              ),
            },
          ),
        ),
      );
}
