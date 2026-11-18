import 'dart:async';

import 'package:sat_east_client/core/attempts/save_outcome.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/mock/domain/entities/mock_entities.dart';
import 'package:sat_east_client/features/mock/domain/repositories/mock_repository.dart';

const fakeCourseId = 'sat-course';
const fakeGroupId = 'group-1';

const fakeHub = MockHub(
  passedTopics: 7,
  forms: [
    MockHubForm(
      formNo: 1,
      k: 1,
      need: 3,
      state: MockFormState.finished,
    ),
    MockHubForm(
      formNo: 2,
      k: 2,
      need: 6,
      state: MockFormState.available,
    ),
    MockHubForm(
      formNo: 3,
      k: 3,
      need: 12,
      state: MockFormState.locked,
    ),
  ],
  activeGroup: null,
);

const fakeResumeHub = MockHub(
  passedTopics: 7,
  forms: [
    MockHubForm(
      formNo: 1,
      k: 1,
      need: 3,
      state: MockFormState.inProgress,
    ),
    MockHubForm(
      formNo: 2,
      k: 2,
      need: 6,
      state: MockFormState.locked,
    ),
  ],
  activeGroup: fakeGroupId,
);

abstract final class MockHubFixtures {
  static const allStates = MockHub(
    passedTopics: 7,
    forms: [
      MockHubForm(formNo: 1, k: 1, need: 3, state: MockFormState.finished),
      MockHubForm(formNo: 2, k: 2, need: 6, state: MockFormState.inProgress),
      MockHubForm(formNo: 3, k: 3, need: 7, state: MockFormState.available),
      MockHubForm(formNo: 4, k: 4, need: 12, state: MockFormState.locked),
    ],
    activeGroup: fakeGroupId,
  );

  static const empty = MockHub(passedTopics: 0, forms: [], activeGroup: null);
}

/// Hand-written [MockRepository]; set the public fields per test.
class FakeMockRepository implements MockRepository {
  Result<String?> course = const Success(fakeCourseId);
  Result<MockHub> hubResult = const Success(fakeHub);
  Result<MockStage> startResult = const Success(
    MockFinishedStage(groupId: fakeGroupId, resultId: 'r1'),
  );

  /// When set, `hub` and `start` wait for it (to test in-flight guards).
  Completer<void>? hubGate;
  Completer<void>? startGate;

  int courseCalls = 0;
  final hubCalls = <String>[];
  final startCalls = <String>[];

  @override
  Future<Result<String?>> satCourseId() async {
    courseCalls++;
    return course;
  }

  @override
  Future<Result<MockHub>> hub(String courseId) async {
    hubCalls.add(courseId);
    await hubGate?.future;
    return hubResult;
  }

  @override
  Future<Result<MockStage>> start(String courseId) async {
    startCalls.add(courseId);
    await startGate?.future;
    return startResult;
  }

  @override
  Future<Result<MockStage>> session(String groupId) =>
      throw UnimplementedError('session');

  @override
  Future<Result<MockStage>> startModule2(String groupId) =>
      throw UnimplementedError('startModule2');

  @override
  Future<Result<SaveOutcome>> save({
    required String attemptId,
    required String questionId,
    required int timeMs,
    required bool marked,
    required List<String> eliminated,
    required int clientSeq,
    String? answer,
  }) => throw UnimplementedError('save');

  @override
  Future<Result<MockStage>> submit(String attemptId) =>
      throw UnimplementedError('submit');

  @override
  Future<Result<MockResult>> result(String resultId) =>
      throw UnimplementedError('result');
}
