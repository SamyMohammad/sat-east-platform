import 'dart:async';

import 'package:sat_east_client/core/attempts/attempt_question.dart';
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

/// A two-question module (one MCQ `q1`, one SPR `q2`) whose deadline is
/// [remaining] after [serverNow].
MockModule fakeModule({
  required DateTime serverNow,
  int moduleNo = 1,
  Duration remaining = const Duration(minutes: 35),
  Map<String, SavedAnswer> answers = const {},
  int clientSeq = 0,
  String attemptId = 'attempt-1',
  int warnS = 300,
}) => MockModule(
  groupId: fakeGroupId,
  moduleNo: moduleNo,
  attemptId: attemptId,
  title: 'Module $moduleNo',
  timeLimitS: const Duration(minutes: 35).inSeconds,
  deadline: serverNow.add(remaining),
  serverNow: serverNow,
  warnS: warnS,
  questions: const [
    AttemptQuestion(
      id: 'q1',
      kind: AttemptKind.mcq,
      difficulty: null,
      stemMd: 'MCQ',
      choices: [
        AttemptChoice('A', '1'),
        AttemptChoice('B', '2'),
        AttemptChoice('C', '3'),
        AttemptChoice('D', '4'),
      ],
    ),
    AttemptQuestion(
      id: 'q2',
      kind: AttemptKind.spr,
      difficulty: null,
      stemMd: 'SPR',
      choices: [],
    ),
    AttemptQuestion(
      id: 'q3',
      kind: AttemptKind.mcq,
      difficulty: null,
      stemMd: 'MCQ 2',
      choices: [AttemptChoice('A', '1'), AttemptChoice('B', '2')],
    ),
  ],
  answers: answers,
  clientSeq: clientSeq,
);

typedef SavedCall = ({
  String attemptId,
  String questionId,
  String? answer,
  int timeMs,
  bool marked,
  List<String> eliminated,
  int clientSeq,
});

/// Hand-written [MockRepository]; set the public fields per test. A queue
/// entry (`...Queue`) is used before the plain result.
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

  Result<MockStage> sessionResult = const Success(
    MockFinishedStage(groupId: fakeGroupId, resultId: 'r1'),
  );
  final sessionQueue = <Result<MockStage>>[];
  Completer<void>? sessionGate;
  final sessionCalls = <String>[];

  Result<MockStage> startModule2Result = const Success(
    MockFinishedStage(groupId: fakeGroupId, resultId: 'r1'),
  );
  Completer<void>? startModule2Gate;
  final startModule2Calls = <String>[];

  Result<SaveOutcome> saveResult = const Success(SaveOutcome.saved);
  final saveQueue = <Result<SaveOutcome>>[];
  Completer<void>? saveGate;
  final saves = <SavedCall>[];

  Result<MockStage> submitResult = const Success(
    MockFinishedStage(groupId: fakeGroupId, resultId: 'r1'),
  );
  final submitQueue = <Result<MockStage>>[];
  Completer<void>? submitGate;
  final submitCalls = <String>[];

  /// Order of `save` / `submit` calls, to prove the outbox flushes first.
  final events = <String>[];

  Result<MockResult> resultResult = const Success(fakeResult);
  final resultQueue = <Result<MockResult>>[];
  final resultCalls = <String>[];

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
  Future<Result<MockStage>> session(String groupId) async {
    sessionCalls.add(groupId);
    await sessionGate?.future;
    return sessionQueue.isEmpty ? sessionResult : sessionQueue.removeAt(0);
  }

  @override
  Future<Result<MockStage>> startModule2(String groupId) async {
    startModule2Calls.add(groupId);
    await startModule2Gate?.future;
    return startModule2Result;
  }

  @override
  Future<Result<SaveOutcome>> save({
    required String attemptId,
    required String questionId,
    required int timeMs,
    required bool marked,
    required List<String> eliminated,
    required int clientSeq,
    String? answer,
  }) async {
    events.add('save');
    saves.add((
      attemptId: attemptId,
      questionId: questionId,
      answer: answer,
      timeMs: timeMs,
      marked: marked,
      eliminated: eliminated,
      clientSeq: clientSeq,
    ));
    await saveGate?.future;
    return saveQueue.isEmpty ? saveResult : saveQueue.removeAt(0);
  }

  @override
  Future<Result<MockStage>> submit(String attemptId) async {
    events.add('submit');
    submitCalls.add(attemptId);
    await submitGate?.future;
    return submitQueue.isEmpty ? submitResult : submitQueue.removeAt(0);
  }

  @override
  Future<Result<MockResult>> result(String resultId) async {
    resultCalls.add(resultId);
    return resultQueue.isEmpty ? resultResult : resultQueue.removeAt(0);
  }
}

const fakeResult = MockResult(
  id: 'r1',
  route: 'hard',
  rawM1: 18,
  rawM2: 15,
  estLow: 560,
  estHigh: 620,
  domains: [DomainScore(domain: 'Algebra', correct: 9, total: 13)],
);
