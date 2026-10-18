import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/activation/domain/entities/activation_result.dart';
import 'package:sat_east_client/features/activation/presentation/cubit/activation_cubit.dart';
import 'package:sat_east_client/features/activation/presentation/cubit/activation_state.dart';

import '../activation_fixtures.dart';

void main() {
  late FakeActivationRepository repository;

  setUp(() => repository = FakeActivationRepository());

  test('S-10: activation begins idle', () async {
    final cubit = ActivationCubit(repository);
    expect(cubit.state, const ActivationIdle());
    await cubit.close();
  });

  blocTest<ActivationCubit, ActivationState>(
    'S-10: submit emits Submitting then Done and keeps raw code',
    build: () => ActivationCubit(repository),
    act: (cubit) => cubit.submit(' ab12-cd34 ef56 ', DateTime(2027, 3, 15)),
    expect: () => [
      const ActivationSubmitting(),
      ActivationDone(activationResult),
    ],
    verify: (_) =>
        expect(repository.calls, [(' ab12-cd34 ef56 ', DateTime(2027, 3, 15))]),
  );

  for (final code in [
    ErrorCodes.codeInvalid,
    ErrorCodes.codeUsed,
    ErrorCodes.alreadyEnrolled,
    ErrorCodes.rateLimited,
    ErrorCodes.invalidInput,
    ErrorCodes.notAuthenticated,
    ErrorCodes.network,
    ErrorCodes.internal,
  ]) {
    blocTest<ActivationCubit, ActivationState>(
      'S-10: submit maps $code to Failed',
      build: () {
        repository.result = Failure(AppError(code));
        return ActivationCubit(repository);
      },
      act: (cubit) => cubit.submit('code', DateTime(2027, 3, 15)),
      expect: () => [
        const ActivationSubmitting(),
        ActivationFailed(AppError(code)),
      ],
    );
  }

  blocTest<ActivationCubit, ActivationState>(
    'S-10: submit can retry after a failed guess',
    build: () => ActivationCubit(repository),
    act: (cubit) async {
      repository.result = const Failure(AppError(ErrorCodes.codeInvalid));
      await cubit.submit('wrong', DateTime(2027, 3, 15));
      repository.result = Success(activationResult);
      await cubit.submit('right', DateTime(2027, 3, 15));
    },
    expect: () => [
      const ActivationSubmitting(),
      const ActivationFailed(AppError(ErrorCodes.codeInvalid)),
      const ActivationSubmitting(),
      ActivationDone(activationResult),
    ],
  );

  test('S-10: overlapping submits redeem only once', () async {
    final pending = Completer<Result<ActivationResult>>();
    repository.pending = pending.future;
    final cubit = ActivationCubit(repository);
    final first = cubit.submit('first', DateTime(2027, 3, 15));
    await cubit.submit('second', DateTime(2027, 3, 15));
    expect(repository.calls, hasLength(1));
    pending.complete(Success(activationResult));
    await first;
    await cubit.close();
  });

  for (final outcome in <Result<ActivationResult>>[
    Success(activationResult),
    const Failure(AppError(ErrorCodes.network)),
  ]) {
    test('S-10: closed cubit ignores in-flight $outcome', () async {
      final pending = Completer<Result<ActivationResult>>();
      repository.pending = pending.future;
      final cubit = ActivationCubit(repository);
      final emitted = <ActivationState>[];
      final subscription = cubit.stream.listen(emitted.add);
      final request = cubit.submit('code', DateTime(2027, 3, 15));
      await cubit.close();
      pending.complete(outcome);
      await request;
      await subscription.cancel();
      expect(emitted, [const ActivationSubmitting()]);
    });
  }

  test('S-10: submitting after close never calls the repository', () async {
    final cubit = ActivationCubit(repository);
    await cubit.close();

    await cubit.submit('code', DateTime(2027, 3, 15));

    expect(repository.calls, isEmpty);
  });
}
