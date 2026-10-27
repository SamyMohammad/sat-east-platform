import 'dart:async';

import 'package:flutter/material.dart';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:sat_east_client/core/theme/app_icons.dart';
import 'package:sat_east_client/core/theme/app_tokens.dart';
import 'package:sat_east_client/core/theme/app_type.dart';
import 'package:sat_east_client/features/teacher/questions/presentation/bank_copy.dart';
import 'package:sat_east_client/features/teacher/questions/presentation/cubit/question_bank_cubit.dart';
import 'package:sat_east_client/features/teacher/questions/presentation/cubit/question_bank_state.dart';
import 'package:sat_east_client/features/teacher/questions/presentation/widgets/bank_table.dart';
import 'package:sat_east_client/shared/widgets/app_illustration.dart';
import 'package:sat_east_client/shared/widgets/app_skeleton.dart';
import 'package:sat_east_client/shared/widgets/empty_state.dart';
import 'package:sat_east_client/shared/widgets/error_retry.dart';

class BankResults extends StatelessWidget {
  const BankResults({super.key});
  @override
  Widget build(BuildContext context) =>
      BlocBuilder<QuestionBankCubit, QuestionBankState>(
        builder: (context, state) {
          if (state.loading) {
            return const Padding(
              padding: EdgeInsets.all(AppSpace.s4),
              child: AppSkeleton(),
            );
          }
          final cubit = context.read<QuestionBankCubit>();
          if (state.error case final error?) {
            return ErrorRetry(
              title: bankErrorCopy(error.code),
              message: '',
              onRetry: () => unawaited(cubit.retry()),
            );
          }
          final page = state.bank;
          if (page == null) return const SizedBox.shrink();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: AppSpace.s4,
            children: [
              if (page.rows.isEmpty)
                const EmptyState(
                  title: 'No questions found.',
                  message: '',
                  illustration: AppIllustrationName.emptyCourses,
                )
              else
                BankTable(page: page),
              Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    page.rows.isEmpty
                        ? '0 of ${page.total}'
                        : '${page.start}\u2013${page.end} of ${page.total}',
                    style: AppType.count,
                  ),
                  IconButton(
                    tooltip: 'Previous page',
                    onPressed: page.hasPrevious
                        ? () => unawaited(cubit.prevPage())
                        : null,
                    icon: const Icon(AppIcons.previous),
                  ),
                  IconButton(
                    tooltip: 'Next page',
                    onPressed: page.hasNext
                        ? () => unawaited(cubit.nextPage())
                        : null,
                    icon: const Icon(AppIcons.next),
                  ),
                ],
              ),
            ],
          );
        },
      );
}
