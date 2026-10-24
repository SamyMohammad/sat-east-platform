import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/teacher/review/domain/entities/review.dart';

abstract interface class ReviewRepository {
  Future<Result<ReviewPage>> list(ReviewSection section, int page);
  Future<Result<List<QuestionReport>>> reports(String questionId);
  Future<Result<int>> resolve(String questionId, String outcome, String? note);
  Future<Result<ReviewCounts>> counts();
}
