import 'dart:async';

import 'package:flutter/material.dart';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:sat_east_client/core/di/injection.dart';
import 'package:sat_east_client/core/theme/app_colors.dart';
import 'package:sat_east_client/core/theme/app_tokens.dart';
import 'package:sat_east_client/features/teacher/questions/presentation/cubit/question_import_cubit.dart';
import 'package:sat_east_client/features/teacher/questions/presentation/cubit/question_import_state.dart';
import 'package:sat_east_client/features/teacher/questions/presentation/import_copy.dart';
import 'package:sat_east_client/features/teacher/questions/presentation/widgets/import_report_card.dart';
import 'package:sat_east_client/shared/widgets/app_banner.dart';
import 'package:sat_east_client/shared/widgets/app_skeleton.dart';

class QuestionImportScreen extends StatelessWidget {
  const QuestionImportScreen({super.key});
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => getIt<QuestionImportCubit>(),
    child: const QuestionImportView(),
  );
}

class QuestionImportView extends StatelessWidget {
  const QuestionImportView({super.key});
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(AppSpace.s4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpace.s4,
      children: [
        Text(
          'Import questions',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        BlocBuilder<QuestionImportCubit, QuestionImportState>(
          builder: (context, state) {
            final cubit = context.read<QuestionImportCubit>();
            return switch (state) {
              ImportIdle() => Card(
                margin: EdgeInsets.zero,
                elevation: 0,
                color: context.appColors.background,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  side: BorderSide(color: context.appColors.line),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpace.s4),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: FilledButton(
                      onPressed: () => unawaited(cubit.pick()),
                      child: const Text('Choose file'),
                    ),
                  ),
                ),
              ),
              ImportReading() ||
              ImportValidating() ||
              ImportCommitting() => const Padding(
                padding: EdgeInsets.all(AppSpace.s4),
                child: AppSkeleton(),
              ),
              ImportReported(:final file, :final report) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: AppSpace.s4,
                children: [
                  Card(
                    margin: EdgeInsets.zero,
                    elevation: 0,
                    color: context.appColors.background,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.card),
                      side: BorderSide(color: context.appColors.line),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpace.s4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            file.name,
                            textDirection: TextDirection.ltr,
                          ),
                          Text('${report.rows} rows'),
                        ],
                      ),
                    ),
                  ),
                  ImportReportCard(report: report),
                  Wrap(
                    spacing: AppSpace.s3,
                    runSpacing: AppSpace.s3,
                    children: [
                      FilledButton(
                        onPressed: report.canCommit
                            ? () => unawaited(cubit.commit())
                            : null,
                        child: Text('Import ${report.rows} questions'),
                      ),
                      TextButton(
                        onPressed: () => unawaited(cubit.validate()),
                        child: const Text('Validate again'),
                      ),
                      TextButton(
                        onPressed: cubit.reset,
                        child: const Text('Choose another file'),
                      ),
                    ],
                  ),
                ],
              ),
              ImportCommitted(:final report) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: AppSpace.s4,
                children: [
                  Text('Imported ${report.rows} questions'),
                  ImportReportCard(report: report),
                  TextButton(
                    onPressed: cubit.reset,
                    child: const Text('Import another'),
                  ),
                ],
              ),
              ImportFailed(:final error) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: AppSpace.s4,
                children: [
                  AppBanner(
                    message: importErrorCopy(error.code),
                    kind: AppBannerKind.error,
                  ),
                  TextButton(
                    onPressed: cubit.reset,
                    child: const Text('Choose file'),
                  ),
                ],
              ),
            };
          },
        ),
      ],
    ),
  );
}
