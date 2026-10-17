import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/quiz/domain/entities/quiz.dart';

abstract interface class QuizRepository {
  Future<Result<QuizSession>> start(String topicId);

  Future<Result<SaveOutcome>> save({
    required String attemptId,
    required String questionId,
    required int timeMs,
    required bool marked,
    required List<String> eliminated,
    required int clientSeq,
    String? answer,
  });

  Future<Result<QuizReport>> submit(String attemptId);
}
