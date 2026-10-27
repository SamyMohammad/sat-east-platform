import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/teacher/review/domain/entities/review.dart';
import 'package:sat_east_client/features/teacher/review/domain/usecases/review_actions.dart';
import 'package:sat_east_client/features/teacher/review/presentation/cubit/review_counts_cubit.dart';
import 'package:sat_east_client/features/teacher/review/presentation/cubit/review_queue_cubit.dart';
import 'package:sat_east_client/features/teacher/review/presentation/cubit/review_reports_cubit.dart';

import '../review_fixtures.dart';

void main() {
  test(
    'T-08: failed paging never presents old rows as the requested page',
    () async {
      final repo = FakeReviewRepository();
      final c = ReviewQueueCubit(ReviewActions(repo));
      addTearDown(c.close);
      await c.load(ReviewSection.reported);
      repo.listError = const AppError('network');
      await c.next();
      expect(c.state.page, 2);
      expect(c.state.result, isNull);
      repo.listError = null;
      await c.retry();
      expect(c.state.result?.page, 2);
    },
  );
  test(
    'T-08: invalid resolution never reaches RPC and blank notes are null',
    () async {
      final repo = FakeReviewRepository();
      final actions = ReviewActions(repo);
      expect(await actions.resolve('q1', 'other', null), isA<Failure<int>>());
      expect(
        await actions.resolve('q1', 'fixed', 'a' * 501),
        isA<Failure<int>>(),
      );
      expect(repo.resolutions, isEmpty);
      await actions.resolve('q1', 'fixed', '  ');
      expect(repo.resolutions, [('q1', 'fixed', null)]);
    },
  );
  test('T-08: queue load, next, previous and tab reset', () async {
    final repo = FakeReviewRepository();
    final c = ReviewQueueCubit(ReviewActions(repo));
    addTearDown(c.close);
    await c.load(ReviewSection.reported);
    await c.next();
    await c.next();
    await c.prev();
    await c.prev();
    await c.load(ReviewSection.needsReview);
    expect(repo.pages, [
      (ReviewSection.reported, 1),
      (ReviewSection.reported, 2),
      (ReviewSection.reported, 1),
      (ReviewSection.needsReview, 1),
    ]);
  });
  for (final method in ['load', 'next', 'prev', 'retry']) {
    test('T-08: queue $method failure and retry', () async {
      final repo = FakeReviewRepository();
      final c = ReviewQueueCubit(ReviewActions(repo));
      addTearDown(c.close);
      await c.load(ReviewSection.reported);
      if (method == 'prev') await c.next();
      repo.listError = const AppError('network');
      switch (method) {
        case 'load':
          await c.load(ReviewSection.needsReview);
        case 'next':
          await c.next();
        case 'prev':
          await c.prev();
        case 'retry':
          await c.retry();
      }
      expect(c.state.error?.code, 'network');
      final page = c.state.page;
      repo.listError = null;
      await c.retry();
      expect(c.state.result?.page, page);
      expect(c.state.error, isNull);
    });
  }
  for (final fails in [false, true]) {
    test(
      'T-08: queue resolve ${fails ? 'failure' : 'success'} preserves section/page',
      () async {
        final repo = FakeReviewRepository();
        final c = ReviewQueueCubit(ReviewActions(repo));
        addTearDown(c.close);
        await c.load(ReviewSection.needsReview);
        await c.next();
        if (fails) repo.resolveError = const AppError('forbidden');
        await c.resolve('q2', 'fixed', '  Done  ');
        expect(repo.resolutions, [('q2', 'fixed', 'Done')]);
        expect(c.state.section, ReviewSection.needsReview);
        expect(c.state.page, 2);
        expect(c.state.error?.code, fails ? 'forbidden' : null);
        expect(c.state.resolved, fails ? 0 : 1);
      },
    );
  }
  test('T-08: stale and closed queue requests cannot emit', () async {
    final pending = Completer<Result<ReviewPage>>();
    final repo = FakeReviewRepository()..pending = pending.future;
    final c = ReviewQueueCubit(ReviewActions(repo));
    final old = c.load(ReviewSection.reported);
    repo.pending = null;
    await c.load(ReviewSection.needsReview);
    pending.complete(Success(reviewPage()));
    await old;
    expect(c.state.section, ReviewSection.needsReview);
    await c.close();
    await c.retry();
    expect(c.isClosed, isTrue);
  });
  test('T-08: reports load and resolve success hides old reports', () async {
    final repo = FakeReviewRepository()..reportsValue = openReports;
    final c = ReviewReportsCubit(ReviewActions(repo));
    addTearDown(c.close);
    await c.load('q1');
    expect(c.state.reports, openReports);
    await c.resolve('dismissed', '  Fine  ');
    expect(repo.resolutions, [('q1', 'dismissed', 'Fine')]);
    expect(c.state.reports, isEmpty);
    expect(c.state.resolved, 1);
  });
  test(
    'T-08: reports read/resolve failures preserve editor-independent state and retry',
    () async {
      final repo = FakeReviewRepository()
        ..reportsError = const AppError('network');
      final c = ReviewReportsCubit(ReviewActions(repo));
      addTearDown(c.close);
      await c.load('q1');
      expect(c.state.error?.code, 'network');
      repo
        ..reportsError = null
        ..reportsValue = openReports;
      await c.retry();
      expect(c.state.reports, openReports);
      repo.resolveError = const AppError('forbidden');
      await c.resolve('fixed', null);
      expect(c.state.reports, openReports);
      expect(c.state.error?.code, 'forbidden');
      expect(c.state.resolved, 0);
    },
  );
  test('T-08: counts sum, retry and ignore a closed pending request', () async {
    final repo = FakeReviewRepository()
      ..countsValue = const ReviewCounts(reported: 2, needsReview: 3);
    final c = ReviewCountsCubit(ReviewActions(repo));
    await c.refresh();
    expect(c.state.counts?.total, 5);
    repo.countsError = const AppError('network');
    await c.refresh();
    expect(c.state.error?.code, 'network');
    repo.countsError = null;
    await c.refresh();
    expect(c.state.error, isNull);
    final pending = Completer<Result<ReviewCounts>>();
    repo.pendingCounts = pending.future;
    final loading = c.refresh();
    await c.close();
    pending.complete(const Success(ReviewCounts(reported: 9, needsReview: 9)));
    await loading;
    expect(c.state.counts?.total, isNot(18));
  });
}
