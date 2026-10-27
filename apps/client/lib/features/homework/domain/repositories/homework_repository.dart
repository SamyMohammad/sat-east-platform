import 'package:sat_east_client/core/attempts/save_outcome.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/homework/domain/entities/homework.dart';

abstract interface class HomeworkRepository {
  Future<Result<HomeworkSession>> start(String topicId);

  Future<Result<SaveOutcome>> save({
    required String attemptId,
    required String questionId,
    required int timeMs,
    required bool marked,
    required List<String> eliminated,
    required int clientSeq,
    String? answer,
  });

  Future<Result<HomeworkReport>> submit(String attemptId);
}
