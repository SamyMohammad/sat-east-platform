import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sat_east_client/core/presentation/learning_copy.dart';
import 'package:sat_east_client/core/router/app_router.dart';
import 'package:sat_east_client/core/theme/booklet_tokens.dart';
import 'package:sat_east_client/features/quiz/domain/entities/quiz.dart';
import 'package:sat_east_client/features/quiz/presentation/quiz_copy.dart';
import 'package:sat_east_client/features/quiz/presentation/widgets/quiz_status_content.dart';
import 'package:sat_east_client/shared/widgets/loading_button.dart';

class QuizResultScreen extends StatelessWidget {
  const QuizResultScreen({
    required this.topicId,
    required this.report,
    super.key,
  });

  final String topicId;
  final QuizReport report;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final next = report.nextTopic;
    final retakeAt = report.retakeAt;
    return SafeArea(
      child: QuizStatusContent(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: BookletSpace.s4,
          children: [
            Text(
              report.passed ? QuizCopy.passed : QuizCopy.notPassed,
              style: theme.textTheme.headlineSmall,
            ),
            Text(
              QuizCopy.score(
                report.scoreRaw,
                report.scoreTotal,
                report.scorePct,
              ),
              style: theme.textTheme.titleLarge,
            ),
            Text(QuizCopy.passMark(report.passMark)),
            if (!report.passed)
              Text(
                retakeAt == null
                    ? QuizCopy.retakeUnavailable
                    : QuizCopy.retake(_localTime(context, retakeAt)),
              ),
            LoadingButton(
              label: report.passed
                  ? next == null
                        ? QuizCopy.backToCourse
                        : QuizCopy.nextTopic
                  : LearningCopy.backToTopic,
              onPressed: () => context.go(
                report.passed
                    ? next == null
                          ? AppRoutes.courses
                          : AppRoutes.topic(next.id)
                    : AppRoutes.topic(topicId),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _localTime(BuildContext context, DateTime instant) {
  final local = instant.toLocal();
  final l10n = MaterialLocalizations.of(context);
  final time = l10n.formatTimeOfDay(
    TimeOfDay.fromDateTime(local),
    alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
  );
  return '${l10n.formatMediumDate(local)} $time';
}
