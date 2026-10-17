import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:sat_east_client/core/router/app_router.dart';
import 'package:sat_east_client/features/quiz/domain/entities/quiz.dart';
import 'package:sat_east_client/features/quiz/presentation/cubit/quiz_cubit.dart';
import 'package:sat_east_client/features/quiz/presentation/cubit/quiz_state.dart';
import 'package:sat_east_client/features/quiz/presentation/quiz_copy.dart';
import 'package:sat_east_client/shared/widgets/question_view/answer_state.dart';
import 'package:sat_east_client/shared/widgets/question_view/question_data.dart';
import 'package:sat_east_client/shared/widgets/question_view/question_view.dart';
import 'package:sat_east_client/shared/widgets/question_view/question_view_mode.dart';

Set<int> quizAnsweredIndices(QuizRunning state) => {
  for (var i = 0; i < state.session.questions.length; i++)
    if (state.answers[state.session.questions[i].id]?.trim().isNotEmpty ??
        false)
      i,
};

class QuizQuestionView extends StatelessWidget {
  const QuizQuestionView({required this.topicId, super.key});

  final String topicId;

  @override
  Widget build(BuildContext context) => BlocBuilder<QuizCubit, QuizState>(
    buildWhen: (_, next) => next is QuizRunning,
    builder: (context, state) {
      if (state is! QuizRunning) return const SizedBox.shrink();
      final cubit = context.read<QuizCubit>();
      final session = state.session;
      final question = session.questions[state.index];
      return AbsorbPointer(
        absorbing: state.submitting,
        child: QuestionView(
          title: session.title,
          question: QuestionData(
            id: question.id,
            label: QuizCopy.question(state.index),
            stemMd: question.stemMd,
            kind: switch (question.kind) {
              QuizKind.mcq => McqKind([
                for (final choice in question.choices)
                  ChoiceData(label: choice.label, md: choice.bodyMd),
              ]),
              QuizKind.spr => const SprKind(),
            },
            difficulty: switch (question.difficulty) {
              'E' => QuestionDifficulty.easy,
              'M' => QuestionDifficulty.medium,
              'H' => QuestionDifficulty.hard,
              _ => null,
            },
          ),
          mode: QuizMode(
            title: session.title,
            index: state.index,
            total: session.questions.length,
            remaining: state.remaining,
            timeBudget: session.timeLimit,
            warnAt: session.warnAt,
            timerHidden: state.timerHidden,
            answered: quizAnsweredIndices(state),
            marked: {
              for (var i = 0; i < session.questions.length; i++)
                if (state.marked.contains(session.questions[i].id)) i,
            },
          ),
          answer: AnswerState(
            selected: question.kind == QuizKind.mcq
                ? state.answers[question.id]
                : null,
            sprText: question.kind == QuizKind.spr
                ? state.answers[question.id] ?? ''
                : '',
            marked: state.marked.contains(question.id),
          ),
          onBack: () => context.go(AppRoutes.topic(topicId)),
          onSelect: state.submitting ? null : cubit.select,
          onSprChanged: state.submitting ? null : cubit.sprChanged,
          onMark: state.submitting ? null : cubit.toggleMark,
          onJumpTo: state.submitting ? null : cubit.goTo,
          onNext: state.submitting ? null : cubit.next,
          onPrev: state.submitting ? null : cubit.prev,
          onToggleTimer: cubit.toggleTimer,
          onSubmit: state.submitting ? null : () => unawaited(cubit.submit()),
        ),
      );
    },
  );
}
