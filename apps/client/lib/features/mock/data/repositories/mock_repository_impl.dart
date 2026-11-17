import 'package:sat_east_client/core/attempts/save_outcome.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/auth/domain/entities/my_enrollment.dart';
import 'package:sat_east_client/features/mock/data/datasources/mock_remote_data_source.dart';
import 'package:sat_east_client/features/mock/domain/entities/mock_entities.dart';
import 'package:sat_east_client/features/mock/domain/repositories/mock_repository.dart';

/// Course code of the mock exam course.
const _satCode = 'SAT';

class MockRepositoryImpl implements MockRepository {
  MockRepositoryImpl(this._remote, {required this.listEnrollments});

  final MockRemoteDataSource _remote;

  /// The student's enrolments (`AuthRepository.listMyEnrollments` in DI).
  final Future<Result<List<MyEnrollment>>> Function() listEnrollments;

  @override
  Future<Result<String?>> satCourseId() async {
    final result = await listEnrollments();
    switch (result) {
      case Failure(:final error):
        return Failure(error);
      case Success(:final value):
        for (final enrollment in value) {
          if (enrollment.courseCode == _satCode && !enrollment.isExpired) {
            return Success(enrollment.courseId);
          }
        }
        return const Success(null);
    }
  }

  @override
  Future<Result<MockHub>> hub(String courseId) => _remote.hub(courseId);

  @override
  Future<Result<MockStage>> start(String courseId) => _remote.start(courseId);

  @override
  Future<Result<MockStage>> session(String groupId) => _remote.session(groupId);

  @override
  Future<Result<MockStage>> startModule2(String groupId) =>
      _remote.startModule2(groupId);

  @override
  Future<Result<SaveOutcome>> save({
    required String attemptId,
    required String questionId,
    required int timeMs,
    required bool marked,
    required List<String> eliminated,
    required int clientSeq,
    String? answer,
  }) => _remote.save(
    attemptId: attemptId,
    questionId: questionId,
    answer: answer,
    timeMs: timeMs,
    marked: marked,
    eliminated: eliminated,
    clientSeq: clientSeq,
  );

  @override
  Future<Result<MockStage>> submit(String attemptId) =>
      _remote.submit(attemptId);

  @override
  Future<Result<MockResult>> result(String resultId) =>
      _remote.result(resultId);
}
