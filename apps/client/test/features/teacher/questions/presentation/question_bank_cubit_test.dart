import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/teacher/questions/domain/entities/bank_filter.dart';
import 'package:sat_east_client/features/teacher/questions/domain/entities/bank_page.dart';
import 'package:sat_east_client/features/teacher/questions/domain/entities/topic_option.dart';
import 'package:sat_east_client/features/teacher/questions/presentation/cubit/question_bank_cubit.dart';

import '../bank_fixtures.dart';

void main() {
  late FakeBankRepository repo;
  late FakeBankScheduler scheduler;
  late QuestionBankCubit cubit;
  setUp(() {
    repo = FakeBankRepository();
    scheduler = FakeBankScheduler();
    cubit = QuestionBankCubit(repo, schedule: scheduler.schedule);
  });
  tearDown(() => cubit.close());
  test('QB-06: load fetches topics and page one', () async {
    await cubit.load();
    expect(cubit.state.bank, bankPage);
    expect(cubit.state.topics, bankTopics);
    expect(cubit.state.loading, isFalse);
    expect(repo.calls, [(const BankFilter(), 1)]);
  });
  test('QB-06: topic failure retries metadata', () async {
    repo.topicsResult = const Failure(AppError('network'));
    await cubit.load();
    expect(cubit.state.error?.code, 'network');
    expect(repo.calls, isEmpty);
    repo.topicsResult = Success(bankTopics);
    await cubit.retry();
    expect(cubit.state.bank, bankPage);
    expect(repo.topicCalls, 2);
  });
  test('QB-06: list failure retries current filter and page', () async {
    await cubit.load();
    repo.listResult = const Failure(AppError('forbidden'));
    await cubit.setFilter(const BankFilter(status: 'draft'));
    expect(cubit.state.error?.code, 'forbidden');
    repo.listResult = Success(bankPage);
    await cubit.retry();
    expect(repo.calls.last, (const BankFilter(status: 'draft'), 1));
    expect(repo.topicCalls, 1);
  });
  test(
    'QB-06: filter changes reset to page one and equal filter does nothing',
    () async {
      await cubit.load();
      await cubit.nextPage();
      await cubit.setFilter(const BankFilter(type: 'spr'));
      expect(repo.calls.last, (const BankFilter(type: 'spr'), 1));
      final count = repo.calls.length;
      await cubit.setFilter(const BankFilter(type: 'spr'));
      expect(repo.calls.length, count);
    },
  );
  test(
    'QB-06: search debounce cancels earlier terms without real timers',
    () async {
      await cubit.load();
      await cubit.setFilter(const BankFilter(q: 'x'));
      await cubit.setFilter(const BankFilter(q: 'xy'));
      expect(repo.calls.length, 1);
      expect(scheduler.pending, 1);
      expect(cubit.state.loading, isTrue);
      final loaded = cubit.stream.firstWhere((s) => !s.loading);
      scheduler.fire();
      await loaded;
      expect(repo.calls.last, (const BankFilter(q: 'xy'), 1));
      expect(scheduler.cancellations, 1);
    },
  );
  test(
    'QB-06: non-search filter cancels pending search and sends latest text',
    () async {
      await cubit.load();
      await cubit.setFilter(const BankFilter(q: 'x'));
      await cubit.setFilter(const BankFilter(q: 'x', status: 'draft'));
      expect(scheduler.pending, 0);
      expect(repo.calls.last, (const BankFilter(q: 'x', status: 'draft'), 1));
    },
  );
  test('QB-06: paging respects server bounds and previous page', () async {
    await cubit.load();
    await cubit.prevPage();
    expect(repo.calls.length, 1);
    repo.listResult = Success(
      BankPage(
        total: 3,
        page: 2,
        pageSize: 2,
        rows: bankPage.rows.take(1).toList(),
      ),
    );
    await cubit.nextPage();
    expect(repo.calls.last.$2, 2);
    await cubit.nextPage();
    expect(repo.calls.length, 2);
    await cubit.prevPage();
    expect(repo.calls.last.$2, 1);
  });
  test('QB-06: next-page failure can retry that page', () async {
    await cubit.load();
    repo.listResult = const Failure(AppError('network'));
    await cubit.nextPage();
    expect(cubit.state.error?.code, 'network');
    await cubit.retry();
    expect(repo.calls.last.$2, 2);
  });
  test('QB-06: previous-page failure retries that page', () async {
    await cubit.load();
    repo.listResult = Success(
      BankPage(
        total: 3,
        page: 2,
        pageSize: 2,
        rows: bankPage.rows.take(1).toList(),
      ),
    );
    await cubit.nextPage();
    repo.listResult = const Failure(AppError('network'));
    await cubit.prevPage();
    expect(cubit.state.error?.code, 'network');
    await cubit.retry();
    expect(repo.calls.last.$2, 1);
  });
  test('QB-06: close during list load ignores its result', () async {
    await cubit.load();
    final pending = Completer<Result<BankPage>>();
    repo.pendingList = pending.future;
    final loading = cubit.nextPage();
    await cubit.close();
    pending.complete(Success(bankPage));
    await expectLater(loading, completes);
  });
  test('QB-06: pending old response cannot replace a newer filter', () async {
    await cubit.load();
    final pending = Completer<Result<BankPage>>();
    repo.pendingList = pending.future;
    final old = cubit.nextPage();
    repo.pendingList = null;
    await cubit.setFilter(const BankFilter(type: 'spr'));
    pending.complete(const Failure(AppError('network')));
    await old;
    expect(cubit.state.filter.type, 'spr');
    expect(cubit.state.error, isNull);
  });
  test('QB-06: close cancels search and ignores late metadata', () async {
    final pending = Completer<Result<List<BankCourse>>>();
    repo.pendingTopics = pending.future;
    final loading = cubit.load();
    await cubit.close();
    pending.complete(Success(bankTopics));
    await loading;
    expect(repo.calls, isEmpty);
  });
  test('QB-06: closed cubit cancels scheduled search', () async {
    await cubit.load();
    await cubit.setFilter(const BankFilter(q: 'x'));
    await cubit.close();
    expect(scheduler.pending, 0);
    scheduler.fire();
    expect(repo.calls.length, 1);
  });
}
