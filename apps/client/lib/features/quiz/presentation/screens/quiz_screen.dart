import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:sat_east_client/core/di/injection.dart';
import 'package:sat_east_client/core/presentation/learning_copy.dart';
import 'package:sat_east_client/core/router/app_router.dart';
import 'package:sat_east_client/features/quiz/presentation/cubit/quiz_cubit.dart';
import 'package:sat_east_client/features/quiz/presentation/cubit/quiz_state.dart';
import 'package:sat_east_client/features/quiz/presentation/quiz_copy.dart';
import 'package:sat_east_client/features/quiz/presentation/widgets/quiz_notices.dart';
import 'package:sat_east_client/features/quiz/presentation/widgets/quiz_question.dart';
import 'package:sat_east_client/features/quiz/presentation/widgets/quiz_status_content.dart';
import 'package:sat_east_client/shared/widgets/app_skeleton.dart';
import 'package:sat_east_client/shared/widgets/empty_state.dart';
import 'package:sat_east_client/shared/widgets/question_view/quiz_time_up_dialog.dart';

class QuizScreen extends StatelessWidget {
  const QuizScreen({required this.topicId, super.key});

  final String topicId;

  @override
  Widget build(BuildContext context) => BlocProvider(
    key: ValueKey(topicId),
    create: (_) {
      final cubit = getIt<QuizCubit>();
      unawaited(cubit.start(topicId));
      return cubit;
    },
    child: QuizView(topicId: topicId),
  );
}

class QuizView extends StatefulWidget {
  const QuizView({required this.topicId, super.key});

  final String topicId;

  @override
  State<QuizView> createState() => _QuizViewState();
}

class _QuizViewState extends State<QuizView> {
  QuizRunning? _lastRunning;

  @override
  void initState() {
    super.initState();
    final state = context.read<QuizCubit>().state;
    if (state is QuizRunning) _lastRunning = state;
  }

  void _stateChanged(BuildContext context, QuizState state) {
    switch (state) {
      case QuizRunning():
        _lastRunning = state;
      case QuizSubmitted(:final report):
        void result() {
          if (context.mounted) {
            context.replace(
              AppRoutes.quizResult(widget.topicId),
              extra: report,
            );
          }
        }

        final running = _lastRunning;
        if (running != null && running.remaining <= Duration.zero) {
          unawaited(
            showQuizTimeUpDialog(
              context,
              title: running.session.title,
              answered: quizAnsweredIndices(running).length,
              onContinue: result,
            ),
          );
        } else {
          result();
        }
      case QuizLoading() || QuizFailed():
        _lastRunning = null;
    }
  }

  @override
  Widget build(BuildContext context) => BlocListener<QuizCubit, QuizState>(
    listener: _stateChanged,
    child: SafeArea(
      child: BlocBuilder<QuizCubit, QuizState>(
        buildWhen: (previous, next) =>
            next is! QuizSubmitted &&
            (previous.runtimeType != next.runtimeType || next is QuizFailed),
        builder: (context, state) => switch (state) {
          QuizLoading() || QuizSubmitted() => const QuizStatusContent(
            child: AppSkeleton(),
          ),
          QuizFailed(:final error) => QuizStatusContent(
            child: EmptyState(
              title: QuizCopy.errorTitle(error.code),
              message: QuizCopy.errorBody(error.code),
              actionLabel: LearningCopy.backToTopic,
              onAction: () => context.go(AppRoutes.topic(widget.topicId)),
            ),
          ),
          QuizRunning() => Column(
            children: [
              const QuizNotices(),
              Expanded(child: QuizQuestionView(topicId: widget.topicId)),
            ],
          ),
        },
      ),
    ),
  );
}
