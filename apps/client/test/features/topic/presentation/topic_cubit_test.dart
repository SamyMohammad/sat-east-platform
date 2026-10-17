import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/topic/domain/entities/topic_detail.dart';
import 'package:sat_east_client/features/topic/domain/repositories/topic_repository.dart';
import 'package:sat_east_client/features/topic/presentation/cubit/topic_cubit.dart';
import 'package:sat_east_client/features/topic/presentation/cubit/topic_state.dart';

import '../topic_fixture.dart';

class _Repository extends Mock implements TopicRepository {}

void main() {
  late _Repository repository;
  setUp(() => repository = _Repository());

  blocTest<TopicCubit, TopicState>(
    'PRC-03: load emits loading and server topic',
    build: () {
      when(
        () => repository.getTopic('t1'),
      ).thenAnswer((_) async => const Success(topicFixture));
      return TopicCubit(repository);
    },
    act: (cubit) => cubit.load('t1'),
    expect: () => [const TopicLoading(), const TopicLoaded(topicFixture)],
  );

  for (final code in [
    ErrorCodes.topicLocked,
    ErrorCodes.accessExpired,
    ErrorCodes.notEnrolled,
    ErrorCodes.invalidInput,
    ErrorCodes.network,
    ErrorCodes.internal,
  ]) {
    blocTest<TopicCubit, TopicState>(
      'PRC-03: load propagates $code',
      build: () {
        when(
          () => repository.getTopic('t1'),
        ).thenAnswer((_) async => Failure(AppError(code)));
        return TopicCubit(repository);
      },
      act: (cubit) => cubit.load('t1'),
      expect: () => [const TopicLoading(), TopicFailed(AppError(code))],
    );
  }

  test('PRC-03: close during load emits no late success', () async {
    final response = Completer<Result<TopicDetail>>();
    when(() => repository.getTopic('t1')).thenAnswer((_) => response.future);
    final cubit = TopicCubit(repository);
    final pending = cubit.load('t1');
    await cubit.close();
    response.complete(const Success(topicFixture));
    await expectLater(pending, completes);
  });

  test('PRC-03: a stale response cannot replace the latest load', () async {
    final first = Completer<Result<TopicDetail>>();
    when(() => repository.getTopic('first')).thenAnswer((_) => first.future);
    when(
      () => repository.getTopic('second'),
    ).thenAnswer((_) async => const Failure(AppError(ErrorCodes.topicLocked)));
    final cubit = TopicCubit(repository);
    addTearDown(cubit.close);
    final pending = cubit.load('first');
    await cubit.load('second');
    first.complete(const Success(topicFixture));
    await pending;
    expect(cubit.state, const TopicFailed(AppError(ErrorCodes.topicLocked)));
  });
}
