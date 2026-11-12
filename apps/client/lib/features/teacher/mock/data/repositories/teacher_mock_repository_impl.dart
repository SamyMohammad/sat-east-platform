import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/teacher/mock/data/datasources/teacher_mock_remote_data_source.dart';
import 'package:sat_east_client/features/teacher/mock/domain/entities/mock_entities.dart';
import 'package:sat_east_client/features/teacher/mock/domain/repositories/teacher_mock_repository.dart';

class TeacherMockRepositoryImpl implements TeacherMockRepository {
  TeacherMockRepositoryImpl(this._source);
  final TeacherMockRemoteDataSource _source;

  @override
  Future<Result<MockOverview>> overview(String courseId) =>
      _source.overview(courseId);

  @override
  Future<Result<AssembleResult>> assemble(String courseId, int setNo) =>
      _source.assemble(courseId, setNo);

  @override
  Future<Result<MockForm>> form(String courseId, int setNo, int formNo) =>
      _source.form(courseId, setNo, formNo);

  @override
  Future<Result<List<MockCandidate>>> candidates(
    String courseId,
    int setNo,
    int formNo,
    String questionId,
  ) => _source.candidates(courseId, setNo, formNo, questionId);

  @override
  Future<Result<void>> swap(
    String courseId,
    int setNo,
    int formNo,
    String oldId,
    String newId,
  ) => _source.swap(courseId, setNo, formNo, oldId, newId);

  @override
  Future<Result<void>> deleteDraft(String courseId, int setNo, int formNo) =>
      _source.deleteDraft(courseId, setNo, formNo);

  @override
  Future<Result<PublishResult>> publish(
    String courseId,
    int setNo,
    int formNo,
  ) => _source.publish(courseId, setNo, formNo);
}
