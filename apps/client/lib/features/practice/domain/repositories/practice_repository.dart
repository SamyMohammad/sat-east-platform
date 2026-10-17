import 'package:sat_east_client/core/errors/result.dart';

import 'package:sat_east_client/features/practice/domain/entities/practice.dart';

abstract interface class PracticeRepository {
  Future<Result<PracticeSet>> start(String topicId);

  Future<Result<CheckResult>> check({
    required String attemptId,
    required String questionId,
    required String answer,
    required int timeMs,
  });
}
