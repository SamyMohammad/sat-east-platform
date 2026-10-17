import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sat_east_client/features/quiz/presentation/cubit/quiz_cubit.dart';
import 'package:sat_east_client/features/quiz/presentation/cubit/quiz_state.dart';
import 'package:sat_east_client/features/quiz/presentation/quiz_copy.dart';
import 'package:sat_east_client/shared/widgets/booklet_banner.dart';

class QuizNotices extends StatelessWidget {
  const QuizNotices({super.key});

  @override
  Widget build(BuildContext context) =>
      BlocSelector<QuizCubit, QuizState, (bool, bool, bool)>(
        selector: (state) => switch (state) {
          QuizRunning(
            :final saveError,
            :final submitError,
            :final submitting,
          ) =>
            (saveError != null, submitError != null, submitting),
          _ => (false, false, false),
        },
        builder: (context, flags) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (flags.$1)
              const BookletBanner(
                message: QuizCopy.notSaved,
                kind: BookletBannerKind.offline,
              ),
            if (flags.$2 && !flags.$3)
              BookletBanner(
                message: QuizCopy.submitError,
                kind: BookletBannerKind.error,
                actionLabel: QuizCopy.retrySubmit,
                onAction: () => unawaited(context.read<QuizCubit>().submit()),
              ),
            if (flags.$3) ...[
              const BookletBanner(message: QuizCopy.submitting),
              const LinearProgressIndicator(),
            ],
          ],
        ),
      );
}
