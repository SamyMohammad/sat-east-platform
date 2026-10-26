import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/attempt_review/domain/entities/attempt_review.dart';

// Repository boundary follows ADR-007.
// ignore: one_member_abstracts
abstract interface class AttemptReviewRepository {
  Future<Result<AttemptReview>> load(String attemptId);
}
