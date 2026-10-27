import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/attempt_review/data/datasources/attempt_review_remote_data_source.dart';
import 'package:sat_east_client/features/attempt_review/domain/entities/attempt_review.dart';
import 'package:sat_east_client/features/attempt_review/domain/repositories/attempt_review_repository.dart';

class AttemptReviewRepositoryImpl implements AttemptReviewRepository {
  AttemptReviewRepositoryImpl(this._remote);
  final AttemptReviewRemoteDataSource _remote;
  @override
  Future<Result<AttemptReview>> load(String attemptId) =>
      _remote.load(attemptId);
}
