import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/teacher/review/data/datasources/review_remote_data_source.dart';
import 'package:sat_east_client/features/teacher/review/domain/entities/review.dart';
import 'package:sat_east_client/features/teacher/review/domain/repositories/review_repository.dart';

class ReviewRepositoryImpl implements ReviewRepository {
  const ReviewRepositoryImpl(this._source);
  final ReviewRemoteDataSource _source;
  @override
  Future<Result<ReviewPage>> list(ReviewSection section, int page) =>
      _source.list(section, page);
  @override
  Future<Result<List<QuestionReport>>> reports(String id) =>
      _source.reports(id);
  @override
  Future<Result<int>> resolve(String id, String outcome, String? note) =>
      _source.resolve(id, outcome, note);
  @override
  Future<Result<ReviewCounts>> counts() => _source.counts();
}
