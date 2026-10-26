import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sat_east_client/core/di/injection.dart';
import 'package:sat_east_client/core/theme/booklet_tokens.dart';
import 'package:sat_east_client/features/teacher/review/domain/entities/review.dart';
import 'package:sat_east_client/features/teacher/review/presentation/cubit/review_queue_cubit.dart';
import 'package:sat_east_client/features/teacher/review/presentation/widgets/review_error.dart';
import 'package:sat_east_client/features/teacher/review/presentation/widgets/review_queue_table.dart';

class ReviewQueueScreen extends StatefulWidget {
  const ReviewQueueScreen({super.key});
  @override
  State<ReviewQueueScreen> createState() => _ReviewQueueScreenState();
}

class _ReviewQueueScreenState extends State<ReviewQueueScreen> {
  late final ReviewQueueCubit _cubit;
  @override
  void initState() {
    super.initState();
    _cubit = getIt<ReviewQueueCubit>();
    unawaited(_cubit.load(ReviewSection.reported));
  }

  @override
  void dispose() {
    unawaited(_cubit.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(BookletSpace.s4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Review queue', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: BookletSpace.s4),
        BlocSelector<ReviewQueueCubit, ReviewQueueState, ReviewSection>(
          bloc: _cubit,
          selector: (s) => s.section,
          builder: (context, section) => Row(
            children: [
              for (final tab in ReviewSection.values)
                Expanded(
                  child: Semantics(
                    selected: section == tab,
                    child: TextButton(
                      onPressed: () => unawaited(_cubit.load(tab)),
                      style: TextButton.styleFrom(
                        backgroundColor: section == tab
                            ? Theme.of(context).colorScheme.primaryContainer
                            : null,
                      ),
                      child: Text(
                        tab == ReviewSection.reported
                            ? 'Reported'
                            : 'Needs review',
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: BookletSpace.s3),
        Expanded(
          child: BlocBuilder<ReviewQueueCubit, ReviewQueueState>(
            bloc: _cubit,
            builder: (context, state) => SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (state.loading) const LinearProgressIndicator(),
                  if (state.error case final error?)
                    ReviewError(
                      code: error.code,
                      onRetry: () => unawaited(_cubit.retry()),
                    ),
                  if (state.result case final page?) ...[
                    if (page.rows.isEmpty && !state.loading)
                      const Padding(
                        padding: EdgeInsets.all(BookletSpace.s4),
                        child: Text('No questions to review.'),
                      )
                    else
                      ReviewQueueTable(page: page),
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: BookletSpace.s3,
                      children: [
                        Text(
                          '${page.total} '
                          '${page.total == 1 ? 'question' : 'questions'}',
                        ),
                        Wrap(
                          alignment: WrapAlignment.end,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: BookletSpace.s2,
                          children: [
                            TextButton(
                              onPressed: !state.loading && page.hasPrevious
                                  ? () => unawaited(_cubit.prev())
                                  : null,
                              child: const Text('Previous'),
                            ),
                            Text('Page ${state.page}'),
                            TextButton(
                              onPressed: !state.loading && page.hasNext
                                  ? () => unawaited(_cubit.next())
                                  : null,
                              child: const Text('Next'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
