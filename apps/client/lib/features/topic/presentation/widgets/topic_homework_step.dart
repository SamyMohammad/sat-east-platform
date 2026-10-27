import 'package:flutter/material.dart';
import 'package:sat_east_client/core/theme/app_tokens.dart';
import 'package:sat_east_client/features/homework/presentation/homework_copy.dart';
import 'package:sat_east_client/features/topic/domain/entities/topic_homework.dart';
import 'package:sat_east_client/shared/widgets/loading_button.dart';

class TopicHomeworkStep extends StatelessWidget {
  const TopicHomeworkStep({
    required this.homework,
    super.key,
    this.onStart,
    this.onReport,
  });
  final TopicHomework homework;
  final VoidCallback? onStart;
  final ValueChanged<String>? onReport;
  @override
  Widget build(BuildContext context) {
    final state = homework.state;
    if (state == HomeworkState.skipped) return const SizedBox.shrink();
    final attemptId = homework.attemptId;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppSpace.s3,
      children: [
        Text(
          HomeworkCopy.title,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (state == HomeworkState.submitted) ...[
          Text(HomeworkCopy.submitted(homework.scorePct ?? 0)),
          TextButton(
            onPressed: attemptId == null || onReport == null
                ? null
                : () => onReport!(attemptId),
            child: const Text(HomeworkCopy.viewReport),
          ),
        ] else ...[
          if (state == HomeworkState.lockedByPractice)
            const Text(HomeworkCopy.practiceNeeded),
          LoadingButton(
            label: state == HomeworkState.inProgress
                ? HomeworkCopy.continueHomework(
                    homework.answered,
                    homework.total ?? 0,
                  )
                : HomeworkCopy.start,
            onPressed: state == HomeworkState.lockedByPractice ? null : onStart,
          ),
        ],
      ],
    );
  }
}
