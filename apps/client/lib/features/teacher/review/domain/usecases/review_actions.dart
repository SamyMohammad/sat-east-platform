import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/teacher/review/domain/entities/review.dart';
import 'package:sat_east_client/features/teacher/review/domain/repositories/review_repository.dart';

class ReviewActions {
  const ReviewActions(this._repository);
  final ReviewRepository _repository;
  Future<Result<ReviewPage>> list(ReviewSection section, int page) =>
      _repository.list(section, page);
  Future<Result<List<QuestionReport>>> reports(String id) =>
      _repository.reports(id);
  Future<Result<ReviewCounts>> counts() => _repository.counts();
  Future<Result<int>> resolve(String id, String outcome, String? note) async {
    final trimmed = note?.trim();
    if ((outcome != 'fixed' && outcome != 'dismissed') ||
        (trimmed?.length ?? 0) > 500) {
      return const Failure(AppError(ErrorCodes.invalidInput));
    }
    return _repository.resolve(
      id,
      outcome,
      trimmed == null || trimmed.isEmpty ? null : trimmed,
    );
  }
}
