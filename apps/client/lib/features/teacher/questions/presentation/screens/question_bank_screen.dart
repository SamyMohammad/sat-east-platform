import 'dart:async';

import 'package:flutter/material.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:sat_east_client/core/di/injection.dart';
import 'package:sat_east_client/core/theme/app_tokens.dart';
import 'package:sat_east_client/features/teacher/questions/presentation/cubit/question_bank_cubit.dart';
import 'package:sat_east_client/features/teacher/questions/presentation/widgets/bank_filter_bar.dart';
import 'package:sat_east_client/features/teacher/questions/presentation/widgets/bank_results.dart';

class QuestionBankScreen extends StatelessWidget {
  const QuestionBankScreen({super.key});
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) {
      final cubit = getIt<QuestionBankCubit>();
      unawaited(cubit.load());
      return cubit;
    },
    child: const QuestionBankView(),
  );
}

class QuestionBankView extends StatelessWidget {
  const QuestionBankView({super.key});
  @override
  Widget build(BuildContext context) => SizedBox.expand(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpace.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpace.s4,
        children: [
          Text(
            'Question bank',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          Wrap(
            spacing: AppSpace.s3,
            runSpacing: AppSpace.s3,
            children: [
              FilledButton(
                onPressed: () => context.go('/teacher/questions/new'),
                child: const Text('New question'),
              ),
              OutlinedButton(
                onPressed: () => context.go('/teacher/questions/import'),
                child: const Text('Import'),
              ),
            ],
          ),
          const BankFilterBar(),
          const BankResults(),
        ],
      ),
    ),
  );
}
