import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/home/domain/entities/home_summary.dart';
import 'package:sat_east_client/features/home/domain/usecases/get_home_summary.dart';
import 'package:sat_east_client/features/home/presentation/cubit/home_cubit.dart';
import 'package:sat_east_client/features/home/presentation/cubit/home_state.dart';

class _GetSummary extends Mock implements GetHomeSummary {}

void main() {
  late _GetSummary getSummary;
  const summary = HomeNotEnrolled('Student');
  const error = AppError(ErrorCodes.network);
  setUp(() {
    getSummary = _GetSummary();
    when(getSummary.call).thenAnswer((_) async => const Success(summary));
  });
  blocTest<HomeCubit, HomeState>(
    'LRN-07: load emits loading then loaded',
    build: () => HomeCubit(getSummary),
    act: (cubit) => cubit.load(),
    expect: () => [const HomeLoading(), const HomeLoaded(summary)],
  );
  blocTest<HomeCubit, HomeState>(
    'LRN-07: load failure emits failed',
    setUp: () =>
        when(getSummary.call).thenAnswer((_) async => const Failure(error)),
    build: () => HomeCubit(getSummary),
    act: (cubit) => cubit.load(),
    expect: () => [const HomeLoading(), const HomeFailed(error)],
  );
  blocTest<HomeCubit, HomeState>(
    'LRN-07: retry reloads',
    build: () => HomeCubit(getSummary),
    seed: () => const HomeLoaded(summary),
    act: (cubit) => cubit.retry(),
    expect: () => [const HomeLoading(), const HomeLoaded(summary)],
    verify: (_) => verify(getSummary.call).called(1),
  );
  test('LRN-07: no emit after close', () async {
    final pending = Completer<Result<HomeSummary>>();
    when(getSummary.call).thenAnswer((_) => pending.future);
    final cubit = HomeCubit(getSummary);
    final loading = cubit.load();
    await cubit.close();
    pending.complete(const Success(summary));
    await loading;
    expect(cubit.state, const HomeLoading());
    await cubit.load();
    await cubit.retry();
    verify(getSummary.call).called(1);
  });
  test('LRN-07: older response cannot replace a newer load', () async {
    final older = Completer<Result<HomeSummary>>();
    when(getSummary.call).thenAnswer((_) => older.future);
    final cubit = HomeCubit(getSummary);
    addTearDown(cubit.close);
    final first = cubit.load();
    when(getSummary.call).thenAnswer((_) async => const Success(summary));
    await cubit.retry();
    older.complete(const Failure(error));
    await first;
    expect(cubit.state, const HomeLoaded(summary));
  });
}
