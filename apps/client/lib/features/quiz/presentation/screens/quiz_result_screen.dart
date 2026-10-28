// Feature-local imports follow the project convention.
// ignore_for_file: always_use_package_imports

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sat_east_client/core/presentation/learning_copy.dart';
import 'package:sat_east_client/core/router/app_router.dart';
import 'package:sat_east_client/core/theme/app_tokens.dart';
import 'package:sat_east_client/shared/widgets/app_illustration.dart';
import 'package:sat_east_client/shared/widgets/loading_button.dart';
import 'package:sat_east_client/shared/widgets/skill_breakdown.dart';

import '../../domain/entities/quiz.dart';
import '../quiz_copy.dart';
import '../widgets/quiz_result_score.dart';
import '../widgets/quiz_status_content.dart';

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
    final next = report.nextTopic;
    final retakeAt = report.retakeAt;
    final compact =
        AppLayout.forWidth(MediaQuery.sizeOf(context).width) ==
        AppLayout.compact;
    return SafeArea(
      child: QuizStatusContent(
        maxWidth: 560,
        alignment: Alignment.center,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpace.s4,
          children: [
            AppIllustration(
              report.passed
                  ? AppIllustrationName.quizPassed
                  : AppIllustrationName.quizRetry,
            ),
            QuizResultScore(report: report),
            if (report.skills.isNotEmpty) SkillBreakdown(skills: report.skills),
            if (!report.passed)
              Text(
                textAlign: TextAlign.center,
                retakeAt == null
                    ? QuizCopy.retakeUnavailable
                    : QuizCopy.retake(_localTime(context, retakeAt)),
              ),
            Center(
              child: LoadingButton(
                expanded: compact,
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
            ),
            Center(
              child: LoadingButton(
                expanded: compact,
                variant: AppButtonVariant.secondary,
                label: QuizCopy.reviewAnswers,
                onPressed: () => context.push<void>(
                  AppRoutes.attemptReview(report.attemptId),
                ),
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
