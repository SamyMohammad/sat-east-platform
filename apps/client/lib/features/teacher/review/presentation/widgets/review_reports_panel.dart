import 'dart:async';

import 'package:flutter/material.dart';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:sat_east_client/core/di/injection.dart';
import 'package:sat_east_client/core/theme/app_colors.dart';
import 'package:sat_east_client/core/theme/app_tokens.dart';
import 'package:sat_east_client/features/teacher/review/domain/entities/review.dart';
import 'package:sat_east_client/features/teacher/review/presentation/cubit/review_counts_cubit.dart';
import 'package:sat_east_client/features/teacher/review/presentation/cubit/review_reports_cubit.dart';
import 'package:sat_east_client/features/teacher/review/presentation/review_copy.dart';
import 'package:sat_east_client/features/teacher/review/presentation/widgets/review_error.dart';
import 'package:sat_east_client/features/teacher/review/presentation/widgets/review_resolve_dialog.dart';
import 'package:sat_east_client/features/teacher/shell/teacher_animated_rows.dart';
import 'package:sat_east_client/shared/widgets/app_skeleton.dart';

class ReviewReportsPanel extends StatefulWidget {
  const ReviewReportsPanel({required this.questionId, super.key});
  final String questionId;
  @override
  State<ReviewReportsPanel> createState() => _ReviewReportsPanelState();
}

class _ReviewReportsPanelState extends State<ReviewReportsPanel> {
  late final ReviewReportsCubit _cubit;
  @override
  void initState() {
    super.initState();
    _cubit = getIt<ReviewReportsCubit>();
    unawaited(_cubit.load(widget.questionId));
  }

  @override
  void didUpdateWidget(ReviewReportsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.questionId != widget.questionId) {
      unawaited(_cubit.load(widget.questionId));
    }
  }

  @override
  void dispose() {
    unawaited(_cubit.close());
    super.dispose();
  }

  Future<void> _resolve(String outcome) async {
    final result = await showReviewResolveDialog(context, outcome);
    if (!mounted || result == null) return;
    await _cubit.resolve(outcome, result.note);
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocListener<ReviewReportsCubit, ReviewReportsState>(
    bloc: _cubit,
    listenWhen: (p, n) => p.resolved != n.resolved,
    listener: (context, _) =>
        unawaited(context.read<ReviewCountsCubit>().refresh()),
    child: BlocBuilder<ReviewReportsCubit, ReviewReportsState>(
      bloc: _cubit,
      builder: (context, state) {
        return TeacherAnimatedRows(
          children: [
            if (state.reports.isNotEmpty ||
                state.error != null ||
                state.loading)
              Padding(
                key: const ValueKey('reports-panel'),
                padding: const EdgeInsets.only(bottom: AppSpace.s4),
                child: Card(
                  margin: EdgeInsets.zero,
                  elevation: 0,
                  color: context.appColors.background,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    side: BorderSide(color: context.appColors.line),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpace.s3),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: AppSpace.s3,
                      children: [
                        Text(
                          'Reports',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        if (state.loading || state.resolving)
                          const AppSkeleton(),
                        if (state.error case final error?)
                          ReviewError(
                            code: error.code,
                            onRetry: () => unawaited(_cubit.retry()),
                          ),
                        TeacherAnimatedRows(
                          children: [
                            for (final report in state.reports)
                              _ReportEntry(
                                key: ValueKey(report.id),
                                report: report,
                              ),
                          ],
                        ),
                        if (state.reports.isNotEmpty)
                          Wrap(
                            spacing: AppSpace.s3,
                            children: [
                              FilledButton(
                                onPressed: state.loading || state.resolving
                                    ? null
                                    : () => unawaited(_resolve('fixed')),
                                child: const Text('Mark fixed'),
                              ),
                              OutlinedButton(
                                onPressed: state.loading || state.resolving
                                    ? null
                                    : () => unawaited(_resolve('dismissed')),
                                child: const Text('Not a problem'),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );
}

class _ReportEntry extends StatelessWidget {
  const _ReportEntry({required this.report, super.key});
  final QuestionReport report;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        reviewReasonLabel(report.reason),
        style: Theme.of(context).textTheme.titleSmall,
      ),
      Text(
        report.fullName,
        textDirection: TextDirection.ltr,
      ),
      Text(
        MaterialLocalizations.of(
          context,
        ).formatMediumDate(report.createdAt.toLocal()),
      ),
      if (report.note case final note?)
        Text(note, textDirection: TextDirection.ltr),
    ],
  );
}
