import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/quiz/data/datasources/quiz_remote_data_source.dart';
import 'package:sat_east_client/features/quiz/domain/entities/quiz.dart';
import 'package:sat_east_client/features/quiz/domain/repositories/quiz_repository.dart';

class QuizRepositoryImpl implements QuizRepository {
  QuizRepositoryImpl(this._remote);

  final QuizRemoteDataSource _remote;

  @override
  Future<Result<QuizSession>> start(String topicId) => _remote.start(topicId);

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
  Future<Result<QuizReport>> submit(String attemptId) =>
      _remote.submit(attemptId);
}
