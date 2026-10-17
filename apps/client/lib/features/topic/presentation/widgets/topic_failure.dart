import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/core/presentation/learning_copy.dart';
import 'package:sat_east_client/core/router/app_router.dart';
import 'package:sat_east_client/features/topic/presentation/cubit/topic_cubit.dart';
import 'package:sat_east_client/features/topic/presentation/topic_copy.dart';
import 'package:sat_east_client/shared/widgets/empty_state.dart';
import 'package:sat_east_client/shared/widgets/error_retry.dart';

class TopicFailure extends StatelessWidget {
  const TopicFailure({required this.topicId, required this.error, super.key});

  final String topicId;
  final AppError error;

  @override
  Widget build(BuildContext context) {
    void back() => context.go(AppRoutes.courses);
    final message = switch (error.code) {
      ErrorCodes.topicLocked => LearningCopy.lockedBody,
      ErrorCodes.accessExpired => LearningCopy.expiredBody,
      ErrorCodes.notEnrolled => LearningCopy.notEnrolledBody,
      _ => null,
    };
    if (message != null) {
      return EmptyState(
        title: switch (error.code) {
          ErrorCodes.accessExpired => LearningCopy.expiredTitle,
          ErrorCodes.notEnrolled => LearningCopy.notEnrolledTitle,
          _ => TopicCopy.title,
        },
        message: message,
        actionLabel: TopicCopy.backButton,
        onAction: back,
      );
    }
    return ErrorRetry(
      title: TopicCopy.errorTitle,
      message: TopicCopy.errorBody(error.code),
      onRetry: () => unawaited(context.read<TopicCubit>().load(topicId)),
      secondaryLabel: TopicCopy.backButton,
      onSecondary: back,
    );
  }
}
