import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/mock/domain/entities/mock_entities.dart';
import 'package:sat_east_client/features/mock/presentation/cubit/mock_hub_cubit.dart';
import 'package:sat_east_client/features/mock/presentation/cubit/mock_hub_state.dart';

import '../mock_fakes.dart';

void main() {
  late FakeMockRepository repo;
  late MockHubCubit cubit;

  setUp(() {
    repo = FakeMockRepository();
    cubit = MockHubCubit(repo);
  });
  tearDown(() => cubit.close());

  test('MCK-01: starts in Loading', () {
    expect(cubit.state, isA<MockHubLoading>());
  });

  test('MCK-01: load reads the SAT course then its hub', () async {
    await cubit.load();
    expect(repo.hubCalls, [fakeCourseId]);
    expect(
      cubit.state,
      const MockHubLoaded(courseId: fakeCourseId, hub: fakeHub),
    );
  });

  test('MCK-01: no SAT course shows NoCourse and calls no hub', () async {
    repo.course = const Success(null);
    await cubit.load();
    expect(cubit.state, isA<MockHubNoCourse>());
    expect(repo.hubCalls, isEmpty);
  });

  test('MCK-01: a course lookup failure is Failed', () async {
    repo.course = const Failure(AppError(ErrorCodes.network));
    await cubit.load();
    expect(
      cubit.state,
      const MockHubFailed(AppError(ErrorCodes.network)),
    );
    expect(repo.hubCalls, isEmpty);
  });

  test('MCK-01: a hub failure is Failed and a retry recovers', () async {
    repo.hubResult = const Failure(AppError(ErrorCodes.internal));
    await cubit.load();
    expect(cubit.state, isA<MockHubFailed>());
    repo.hubResult = const Success(fakeHub);
    await cubit.load();
    expect(cubit.state, isA<MockHubLoaded>());
  });

  test('MCK-01: a reload keeps the loaded hub on screen', () async {
    await cubit.load();
    final gate = repo.hubGate = Completer<void>();
    final reload = cubit.load();
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state, isA<MockHubLoaded>());
    gate.complete();
    await reload;
  });

  test(
    'MCK-01: a failed reload keeps the old hub and records the error',
    () async {
      await cubit.load();
      repo.hubResult = const Failure(AppError(ErrorCodes.network));
      await cubit.load();
      expect(
        cubit.state,
        const MockHubLoaded(
          courseId: fakeCourseId,
          hub: fakeHub,
          lastError: AppError(ErrorCodes.network),
        ),
      );
    },
  );

  test('MCK-01: start returns the stage the server answered', () async {
    await cubit.load();
    final stage = await cubit.start();
    expect(repo.startCalls, [fakeCourseId]);
    expect(
      stage,
      const MockFinishedStage(groupId: fakeGroupId, resultId: 'r1'),
    );
    expect((cubit.state as MockHubLoaded).busy, isFalse);
    expect((cubit.state as MockHubLoaded).lastError, isNull);
  });

  test('MCK-01: start before the hub is loaded does nothing', () async {
    expect(await cubit.start(), isNull);
    expect(repo.startCalls, isEmpty);
  });

  for (final code in [
    ErrorCodes.mockLocked,
    ErrorCodes.mockNoneAvailable,
    ErrorCodes.accessExpired,
    ErrorCodes.notEnrolled,
    ErrorCodes.rateLimited,
  ]) {
    test(
      'MCK-01: start failing with $code keeps the hub and sets lastError',
      () async {
        await cubit.load();
        repo.startResult = Failure(AppError(code));
        expect(await cubit.start(), isNull);
        final state = cubit.state as MockHubLoaded;
        expect(state.lastError, AppError(code));
        expect(state.busy, isFalse);
        expect(state.hub, fakeHub);
      },
    );
  }

  test('MCK-01: a second start while busy is ignored', () async {
    await cubit.load();
    final gate = repo.startGate = Completer<void>();
    final first = cubit.start();
    await Future<void>.delayed(Duration.zero);
    expect((cubit.state as MockHubLoaded).busy, isTrue);
    expect(await cubit.start(), isNull);
    gate.complete();
    expect(await first, isNotNull);
    expect(repo.startCalls, hasLength(1));
  });

  test('MCK-01: closing mid-flight does not emit or throw', () async {
    await cubit.load();
    final gate = repo.startGate = Completer<void>();
    final pending = cubit.start();
    await Future<void>.delayed(Duration.zero);
    await cubit.close();
    gate.complete();
    expect(await pending, isNull);
  });

  test('MCK-01: loading then closing mid-flight does not emit', () async {
    final gate = repo.hubGate = Completer<void>();
    final pending = cubit.load();
    await Future<void>.delayed(Duration.zero);
    await cubit.close();
    gate.complete();
    await pending;
    expect(cubit.state, isA<MockHubLoading>());
  });
}
