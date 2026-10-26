import 'package:flutter/material.dart';
import 'package:sat_east_client/core/math_render/math_text.dart';
import 'package:sat_east_client/core/theme/booklet_tokens.dart';
import 'package:sat_east_client/features/attempt_review/domain/entities/attempt_review.dart';
import 'package:sat_east_client/features/attempt_review/presentation/attempt_review_copy.dart';
import 'package:sat_east_client/shared/widgets/booklet_chip.dart';

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
    child: Padding(
      padding: const EdgeInsets.all(BookletSpace.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: BookletSpace.s3,
        children: [
          Text(
            AttemptReviewCopy.question(index),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          MathText(question.stemMd),
          for (final choice in question.choices)
            MathText('${choice.label}. ${choice.bodyMd}'),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: BookletChip(
              label: question.isCorrect
                  ? AttemptReviewCopy.correct
                  : AttemptReviewCopy.incorrect,
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
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    spacing: BookletSpace.s3,
    children: [
      Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      Expanded(child: MathText(value)),
    ],
  );
}
