import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/teacher/mock/data/models/mock_models.dart';
import 'package:sat_east_client/features/teacher/mock/domain/entities/mock_entities.dart';
import 'package:sat_east_client/features/teacher/mock/domain/repositories/teacher_mock_repository.dart';

import 'mock_fixtures.dart';

final MockOverview readyOverview = mockOverviewFromJson(overviewJson());
final MockOverview shortOverview = mockOverviewFromJson(
  overviewJson(missing: [shortageCellJson()], noDomain: 3),
);

class FakeTeacherMockRepository implements TeacherMockRepository {
  Result<MockOverview> overviewResult = Success(readyOverview);
  Result<AssembleResult> assembleResult = const Success(
    Assembled(setNo: 1, formNo: 3),
  );
  final calls = <(String, List<Object?>)>[];

  @override
  Future<Result<MockOverview>> overview(String courseId) async {
    calls.add(('overview', [courseId]));
    return overviewResult;
  }

  @override
  Future<Result<AssembleResult>> assemble(String courseId, int setNo) async {
    calls.add(('assemble', [courseId, setNo]));
    return assembleResult;
  }

  @override
  Future<Result<MockForm>> form(String courseId, int setNo, int formNo) async =>
      Success(mockFormFromJson(formJson()));

  @override
  Future<Result<List<MockCandidate>>> candidates(
    String courseId,
    int setNo,
    int formNo,
    String questionId,
  ) async => const Success([]);

  @override
  Future<Result<void>> swap(
    String courseId,
    int setNo,
    int formNo,
    String oldId,
    String newId,
  ) async => const Success(null);

  @override
  Future<Result<void>> deleteDraft(
    String courseId,
    int setNo,
    int formNo,
  ) async => const Success(null);

  @override
  Future<Result<PublishResult>> publish(
    String courseId,
    int setNo,
    int formNo,
  ) async => const Success(Published());
}
