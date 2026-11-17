import 'package:sat_east_client/core/attempts/save_outcome.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/mock/domain/entities/mock_entities.dart';

abstract interface class MockRepository {
  /// The student's active, unexpired SAT enrolment's course id, or null.
  Future<Result<String?>> satCourseId();

  Future<Result<MockHub>> hub(String courseId);

  /// Starts the lowest available form, or resumes the unfinished one.
  Future<Result<MockStage>> start(String courseId);

  Future<Result<MockStage>> session(String groupId);

  Future<Result<MockStage>> startModule2(String groupId);

  Future<Result<SaveOutcome>> save({
    required String attemptId,
    required String questionId,
    required int timeMs,
    required bool marked,
    required List<String> eliminated,
    required int clientSeq,
    String? answer,
  });

  /// For a mock module the server answers with the next stage only.
  Future<Result<MockStage>> submit(String attemptId);

  Future<Result<MockResult>> result(String resultId);
}
