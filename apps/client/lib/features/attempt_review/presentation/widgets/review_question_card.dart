import 'package:flutter/material.dart';

import 'package:sat_east_client/core/math_render/math_text.dart';
import 'package:sat_east_client/core/theme/app_colors.dart';
import 'package:sat_east_client/core/theme/app_icons.dart';
import 'package:sat_east_client/core/theme/app_tokens.dart';
import 'package:sat_east_client/features/attempt_review/domain/entities/attempt_review.dart';
import 'package:sat_east_client/features/attempt_review/presentation/attempt_review_copy.dart';

class ReviewQuestionCard extends StatelessWidget {
  const ReviewQuestionCard({
    required this.question,
    required this.index,
    required this.keysVisible,
    super.key,
  });
  final ReviewQuestion question;
  final int index;
  final bool keysVisible;
  @override
  Widget build(BuildContext context) => Card(
    color: context.appColors.surface,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.card),
      side: BorderSide(color: context.appColors.line),
    ),
    child: Padding(
      padding: const EdgeInsets.all(AppSpace.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpace.s3,
        children: [
          Text(
            AttemptReviewCopy.question(index),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          MathText(question.stemMd),
          for (final choice in question.choices)
            MathText('${choice.label}. ${choice.bodyMd}'),
          Semantics(
            liveRegion: true,
            child: Row(
              spacing: AppSpace.s2,
              children: [
                Icon(
                  question.isCorrect ? AppIcons.correct : AppIcons.incorrect,
                  size: AppSize.iconSmall,
                  color: question.isCorrect
                      ? context.appColors.correct
                      : context.appColors.incorrect,
                ),
                Flexible(
                  child: Text(
                    question.isCorrect
                        ? AttemptReviewCopy.correct
                        : AttemptReviewCopy.incorrect,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: question.isCorrect
                          ? context.appColors.correct
                          : context.appColors.incorrect,
                    ),
                  ),
                ),
              ],
            ),
          ),
          _ReviewDetailRow(
            label: AttemptReviewCopy.myAnswer,
            value: question.myAnswer ?? AttemptReviewCopy.unanswered,
          ),
          if (question.key case final key? when keysVisible)
            _ReviewDetailRow(
              label: AttemptReviewCopy.correctAnswer,
              value: key,
            ),
          if (question.explanationMd case final explanation? when keysVisible)
            _ReviewDetailRow(
              label: AttemptReviewCopy.explanation,
              value: explanation,
            ),
        ],
      ),
    ),
  );
}

class _ReviewDetailRow extends StatelessWidget {
  const _ReviewDetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final labelWidget = Text(
      label,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: context.appColors.inkSecondary,
      ),
    );
    if (MediaQuery.textScalerOf(context).scale(16) > 16) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpace.s1,
        children: [labelWidget, MathText(value)],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppSpace.s3,
      children: [
        labelWidget,
        Expanded(child: MathText(value)),
      ],
    );
  }
}
