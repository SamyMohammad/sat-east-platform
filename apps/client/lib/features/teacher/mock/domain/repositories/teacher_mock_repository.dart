import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/teacher/mock/domain/entities/mock_entities.dart';

abstract interface class TeacherMockRepository {
  Future<Result<MockOverview>> overview(String courseId);
  Future<Result<AssembleResult>> assemble(String courseId, int setNo);
  Future<Result<MockForm>> form(String courseId, int setNo, int formNo);
  Future<Result<List<MockCandidate>>> candidates(
    String courseId,
    int setNo,
    int formNo,
    String questionId,
  );
  Future<Result<void>> swap(
    String courseId,
    int setNo,
    int formNo,
    String oldId,
    String newId,
  );
  Future<Result<void>> deleteDraft(String courseId, int setNo, int formNo);
  Future<Result<PublishResult>> publish(
    String courseId,
    int setNo,
    int formNo,
  );
}
