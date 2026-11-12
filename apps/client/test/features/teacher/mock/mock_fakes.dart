import 'dart:async';

import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/teacher/mock/data/models/mock_models.dart';
import 'package:sat_east_client/features/teacher/mock/domain/entities/mock_entities.dart';
import 'package:sat_east_client/features/teacher/mock/domain/repositories/teacher_mock_repository.dart';

import 'mock_fixtures.dart';

final MockOverview readyOverview = mockOverviewFromJson(overviewJson());
final MockOverview shortOverview = mockOverviewFromJson(
  overviewJson(missing: [shortageCellJson()], noDomain: 3),
);
final MockForm draftForm = mockFormFromJson(formJson());
final MockForm publishedForm = mockFormFromJson(formJson(status: 'published'));
final List<MockCandidate> candidateList = mockCandidatesFromJson(
  candidatesJson(),
);

class FakeTeacherMockRepository implements TeacherMockRepository {
  Result<MockOverview> overviewResult = Success(readyOverview);
  Result<AssembleResult> assembleResult = const Success(
    Assembled(setNo: 1, formNo: 3),
  );
  Result<MockForm> formResult = Success(draftForm);
  Result<List<MockCandidate>> candidatesResult = Success(candidateList);
  Result<void> swapResult = const Success(null);
  Result<void> deleteResult = const Success(null);
  Result<PublishResult> publishResult = const Success(Published());
  final calls = <(String, List<Object?>)>[];

  /// When set, assemble, swap, delete and publish wait on it (busy tests).
  Completer<void>? gate;

  int count(String name) => calls.where((c) => c.$1 == name).length;

  @override
  Future<Result<MockOverview>> overview(String courseId) async {
    calls.add(('overview', [courseId]));
    return overviewResult;
  }

  @override
  Future<Result<AssembleResult>> assemble(String courseId, int setNo) async {
    calls.add(('assemble', [courseId, setNo]));
    await gate?.future;
    return assembleResult;
  }

  @override
  Future<Result<MockForm>> form(String courseId, int setNo, int formNo) async {
    calls.add(('form', [courseId, setNo, formNo]));
    return formResult;
  }

  @override
  Future<Result<List<MockCandidate>>> candidates(
    String courseId,
    int setNo,
    int formNo,
    String questionId,
  ) async {
    calls.add(('candidates', [courseId, setNo, formNo, questionId]));
    return candidatesResult;
  }

  @override
  Future<Result<void>> swap(
    String courseId,
    int setNo,
    int formNo,
    String oldId,
    String newId,
  ) async {
    calls.add(('swap', [courseId, setNo, formNo, oldId, newId]));
    await gate?.future;
    return swapResult;
  }

  @override
  Future<Result<void>> deleteDraft(
    String courseId,
    int setNo,
    int formNo,
  ) async {
    calls.add(('delete', [courseId, setNo, formNo]));
    await gate?.future;
    return deleteResult;
  }

  @override
  Future<Result<PublishResult>> publish(
    String courseId,
    int setNo,
    int formNo,
  ) async {
    calls.add(('publish', [courseId, setNo, formNo]));
    await gate?.future;
    return publishResult;
  }
}
