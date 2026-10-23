import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sat_east_client/core/theme/booklet_tokens.dart';
import 'package:sat_east_client/features/teacher/questions/presentation/bank_copy.dart';
import 'package:sat_east_client/features/teacher/questions/presentation/cubit/question_bank_cubit.dart';
import 'package:sat_east_client/features/teacher/questions/presentation/cubit/question_bank_state.dart';
import 'package:sat_east_client/features/teacher/questions/presentation/widgets/bank_table.dart';

class BankResults extends StatelessWidget {
  const BankResults({super.key});
  @override
  Widget build(BuildContext context) =>
      BlocBuilder<QuestionBankCubit, QuestionBankState>(
        builder: (context, state) {
          if (state.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          final cubit = context.read<QuestionBankCubit>();
          if (state.error case final error?) {
            return Column(
              children: [
                Text(bankErrorCopy(error.code)),
                TextButton(
                  onPressed: () => unawaited(cubit.retry()),
                  child: const Text('Retry'),
                ),
              ],
            );
          }
          final page = state.bank;
          if (page == null) return const SizedBox.shrink();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: BookletSpace.s4,
            children: [
              if (page.rows.isEmpty)
                const Text('No questions found.')
              else
                BankTable(page: page),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    page.rows.isEmpty
                        ? '0 of ${page.total}'
                        : '${page.start}\u2013${page.end} of ${page.total}',
                  ),
                  IconButton(
                    tooltip: 'Previous page',
                    onPressed: page.hasPrevious
                        ? () => unawaited(cubit.prevPage())
                        : null,
                    icon: const Icon(Icons.chevron_left),
                  ),
                  IconButton(
                    tooltip: 'Next page',
                    onPressed: page.hasNext
                        ? () => unawaited(cubit.nextPage())
                        : null,
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ],
          );
        },
      );
}
