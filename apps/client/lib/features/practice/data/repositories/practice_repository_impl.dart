import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/practice/data/datasources/practice_remote_data_source.dart';
import 'package:sat_east_client/features/practice/domain/entities/practice.dart';
import 'package:sat_east_client/features/practice/domain/repositories/practice_repository.dart';

class PracticeRepositoryImpl implements PracticeRepository {
  PracticeRepositoryImpl(this._remote);

  final PracticeRemoteDataSource _remote;

  @override
  Future<Result<PracticeSet>> start(String topicId) => _remote.start(topicId);

  @override
  Future<Result<void>> report(String questionId, String reason, String? note) =>
      _remote.report(questionId, reason, note);

  @override
  Future<Result<CheckResult>> check({
    required String attemptId,
    required String questionId,
    required String answer,
    required int timeMs,
  }) => _remote.check(
    attemptId: attemptId,
    questionId: questionId,
    answer: answer,
    timeMs: timeMs,
  );
}
