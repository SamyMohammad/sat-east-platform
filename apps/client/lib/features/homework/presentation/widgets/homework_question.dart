import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:sat_east_client/core/attempts/attempt_question.dart';
import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/router/app_router.dart';
import 'package:sat_east_client/features/homework/presentation/cubit/homework_cubit.dart';
import 'package:sat_east_client/features/homework/presentation/cubit/homework_state.dart';
import 'package:sat_east_client/features/homework/presentation/homework_copy.dart';
import 'package:sat_east_client/shared/widgets/question_view/answer_state.dart';
import 'package:sat_east_client/shared/widgets/question_view/question_data.dart';
import 'package:sat_east_client/shared/widgets/question_view/question_view.dart';
import 'package:sat_east_client/shared/widgets/question_view/question_view_mode.dart';

class HomeworkQuestionView extends StatelessWidget {
  const HomeworkQuestionView({
    required this.topicId,
    required this.state,
    super.key,
  });
  final String topicId;
  final HomeworkRunning state;
  @override
  Widget build(BuildContext context) {
    final cubit = context.read<HomeworkCubit>();
    final session = state.session;
    final question = session.questions[state.index];
    final error = state.saveError;
    final saveStatus = error != null
        ? error.code == ErrorCodes.network
              ? SaveStatus.offline
              : SaveStatus.failed
        : state.saving
        ? SaveStatus.saving
        : SaveStatus.saved;
    return AbsorbPointer(
      absorbing: state.submitting,
      child: QuestionView(
        title: session.title,
        question: QuestionData(
          id: question.id,
          label: HomeworkCopy.question(state.index),
          stemMd: question.stemMd,
          kind: switch (question.kind) {
            AttemptKind.mcq => McqKind([
              for (final c in question.choices)
                ChoiceData(label: c.label, md: c.bodyMd),
            ]),
            AttemptKind.spr => const SprKind(),
          },
          difficulty: switch (question.difficulty) {
            'E' => QuestionDifficulty.easy,
            'M' => QuestionDifficulty.medium,
            'H' => QuestionDifficulty.hard,
            _ => null,
          },
        ),
        mode: HomeworkMode(
          title: session.title,
          index: state.index,
          total: session.questions.length,
          saveStatus: saveStatus,
          answered: {
            for (var i = 0; i < session.questions.length; i++)
              if (state.answers[session.questions[i].id]?.trim().isNotEmpty ??
                  false)
                i,
          },
          marked: {
            for (var i = 0; i < session.questions.length; i++)
              if (state.marked.contains(session.questions[i].id)) i,
          },
        ),
        answer: AnswerState(
          selected: question.kind == AttemptKind.mcq
              ? state.answers[question.id]
              : null,
          sprText: question.kind == AttemptKind.spr
              ? state.answers[question.id] ?? ''
              : '',
          marked: state.marked.contains(question.id),
          eliminated: state.eliminated[question.id] ?? const {},
        ),
        onBack: () => context.go(AppRoutes.topic(topicId)),
        onSelect: state.submitting ? null : cubit.select,
        onSprChanged: state.submitting ? null : cubit.sprChanged,
        onMark: state.submitting ? null : cubit.toggleMark,
        onEliminate: state.submitting ? null : cubit.eliminate,
        onRestore: state.submitting ? null : cubit.restore,
        onJumpTo: state.submitting ? null : cubit.goTo,
        onNext: state.submitting ? null : cubit.next,
        onPrev: state.submitting ? null : cubit.prev,
        onSubmit: state.submitting ? null : () => unawaited(cubit.submit()),
        onRetrySave: state.submitting
            ? null
            : () => unawaited(cubit.retrySave()),
      ),
    );
  }
}
