import 'dart:async';

import 'package:flutter/material.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:sat_east_client/core/router/app_router.dart';
import 'package:sat_east_client/features/practice/domain/entities/practice.dart'
    as domain;
import 'package:sat_east_client/features/practice/presentation/cubit/practice_cubit.dart';
import 'package:sat_east_client/features/practice/presentation/cubit/practice_state.dart'
    as practice;
import 'package:sat_east_client/features/practice/presentation/practice_copy.dart';
import 'package:sat_east_client/shared/widgets/booklet_banner.dart';
import 'package:sat_east_client/shared/widgets/question_view/answer_state.dart';
import 'package:sat_east_client/shared/widgets/question_view/practice_feedback.dart';
import 'package:sat_east_client/shared/widgets/question_view/question_data.dart';
import 'package:sat_east_client/shared/widgets/question_view/question_view.dart';
import 'package:sat_east_client/shared/widgets/question_view/question_view_mode.dart';

class PracticeQuestionView extends StatelessWidget {
  const PracticeQuestionView({
    required this.title,
    required this.progress,
    super.key,
  });

  final String title;
  final practice.PracticeInProgress progress;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<PracticeCubit>();
    final question = progress.set.questions[progress.index];
    return Column(
      children: [
        if (progress.checkError != null)
          const BookletBanner(
            message: PracticeCopy.checkError,
            kind: BookletBannerKind.error,
          ),
        Expanded(
          child: QuestionView(
            title: title,
            question: QuestionData(
              id: question.id,
              label: 'Question ${progress.index + 1}',
              stemMd: question.stemMd,
              kind: switch (question.kind) {
                domain.PracticeKind.mcq => McqKind([
                  for (final choice in question.choices)
                    ChoiceData(label: choice.label, md: choice.bodyMd),
                ]),
                domain.PracticeKind.spr => const SprKind(),
              },
              difficulty: switch (question.difficulty) {
                'E' => QuestionDifficulty.easy,
                'M' => QuestionDifficulty.medium,
                'H' => QuestionDifficulty.hard,
                _ => null,
              },
            ),
            mode: PracticeMode(
              feedback: _feedback(progress),
              rep: progress.index + 1,
              repTarget: progress.set.repTarget,
            ),
            answer: AnswerState(
              selected: progress.selected,
              sprText: progress.sprText,
            ),
            onBack: () => context.go(AppRoutes.courses),
            onSelect: cubit.select,
            onSprChanged: cubit.sprChanged,
            onCheck: () => unawaited(cubit.check()),
            onNext: cubit.next,
          ),
        ),
      ],
    );
  }
}

PracticeFeedback _feedback(practice.PracticeInProgress progress) =>
    switch (progress.feedback) {
      practice.Answering() => const Idle(),
      practice.Checking() => const Checking(),
      practice.MissedOnce(
        :final missed,
        :final hintMd,
        :final misconceptionMd,
      ) =>
        FirstMiss(missed: missed, hintMd: hintMd, noteMd: misconceptionMd),
      practice.Done(:final result) => switch (result) {
        domain.CheckCorrect(:final explanationMd) => Correct(
          explanationMd: explanationMd,
          firstTry: progress.firstTry,
        ),
        domain.CheckRevealed(:final key, :final explanationMd) => Revealed(
          key: switch (key) {
            domain.ChoiceReveal(:final label) => McqAnswerKey(label),
            domain.TextReveal(:final text) => SprAnswerKey(text),
          },
          // A lost first reply can leave the first answer unknown.
          firstTry: progress.firstTry ?? '',
          explanationMd: explanationMd,
        ),
        domain.CheckMiss(:final hintMd, :final misconceptionMd) => FirstMiss(
          missed: progress.firstTry ?? '',
          hintMd: hintMd,
          noteMd: misconceptionMd,
        ),
      },
    };
