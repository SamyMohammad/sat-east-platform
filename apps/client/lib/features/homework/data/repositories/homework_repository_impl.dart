import 'package:sat_east_client/core/attempts/save_outcome.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/homework/data/datasources/homework_remote_data_source.dart';
import 'package:sat_east_client/features/homework/domain/entities/homework.dart';
import 'package:sat_east_client/features/homework/domain/repositories/homework_repository.dart';

class HomeworkRepositoryImpl implements HomeworkRepository {
  HomeworkRepositoryImpl(this._remote);

  final HomeworkRemoteDataSource _remote;

  @override
  Future<Result<HomeworkSession>> start(String topicId) =>
      _remote.start(topicId);

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
  Future<Result<HomeworkReport>> submit(String attemptId) =>
      _remote.submit(attemptId);
}
