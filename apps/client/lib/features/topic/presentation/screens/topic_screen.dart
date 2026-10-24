import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:sat_east_client/core/di/injection.dart';
import 'package:sat_east_client/core/router/app_router.dart';
import 'package:sat_east_client/core/router/route_refresh_listener.dart';
import 'package:sat_east_client/core/theme/booklet_tokens.dart';
import 'package:sat_east_client/features/quiz/presentation/quiz_entry.dart';
import 'package:sat_east_client/features/topic/presentation/cubit/topic_cubit.dart';
import 'package:sat_east_client/features/topic/presentation/cubit/topic_state.dart';
import 'package:sat_east_client/features/topic/presentation/widgets/topic_content.dart';
import 'package:sat_east_client/features/topic/presentation/widgets/topic_failure.dart';
import 'package:sat_east_client/shared/widgets/booklet_skeleton.dart';

class TopicScreen extends StatelessWidget {
  const TopicScreen({required this.topicId, super.key, this.title});

  final String topicId;
  final String? title;

  @override
  Widget build(BuildContext context) => BlocProvider(
    key: ValueKey(topicId),
    create: (_) {
      final cubit = getIt<TopicCubit>();
      unawaited(cubit.load(topicId));
      return cubit;
    },
    child: TopicView(topicId: topicId, title: title),
  );
}

class TopicView extends StatelessWidget {
  const TopicView({required this.topicId, super.key, this.title});

  final String topicId;
  final String? title;

  @override
  Widget build(BuildContext context) => RouteRefreshListener(
    location: AppRoutes.topic(topicId),
    onRefresh: () => unawaited(context.read<TopicCubit>().load(topicId)),
    child: SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: BookletSize.readingColumn,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(BookletSpace.s4),
            child: BlocBuilder<TopicCubit, TopicState>(
              builder: (context, state) => switch (state) {
                TopicLoading() => const BookletSkeleton(),
                TopicFailed(:final error) => TopicFailure(
                  topicId: topicId,
                  error: error,
                ),
                TopicLoaded(:final topic) => TopicContent(
                  topic: topic,
                  title: title,
                  onNotes: (note) => unawaited(
                    context.push<void>(AppRoutes.notes(topicId, note.assetId)),
                  ),
                  onPractice: () => unawaited(
                    context.push<void>(
                      AppRoutes.practice(topicId),
                      extra: title ?? topic.title,
                    ),
                  ),
                  onQuiz: () => unawaited(
                    context.push<void>(
                      AppRoutes.quiz(topicId),
                      extra: QuizEntry.startOrResume,
                    ),
                  ),
                ),
              },
            ),
          ),
        ),
      ),
    ),
  );
}
