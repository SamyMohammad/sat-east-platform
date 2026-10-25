import 'package:flutter/material.dart';
import 'package:sat_east_client/core/math_render/math_text.dart';
import 'package:sat_east_client/core/theme/booklet_tokens.dart';
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
          Text(
            question.isCorrect
                ? AttemptReviewCopy.correct
                : AttemptReviewCopy.incorrect,
          ),
          const Text(AttemptReviewCopy.myAnswer),
          MathText(question.myAnswer ?? AttemptReviewCopy.unanswered),
          if (question.key case final key? when keysVisible) ...[
            const Text(AttemptReviewCopy.correctAnswer),
            MathText(key),
          ],
          if (question.explanationMd case final explanation?
              when keysVisible) ...[
            const Text(AttemptReviewCopy.explanation),
            MathText(explanation),
          ],
        ],
      ),
    ),
  );
}
