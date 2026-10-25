import 'package:equatable/equatable.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/attempt_review/domain/entities/attempt_review.dart';

sealed class AttemptReviewState extends Equatable {
  const AttemptReviewState();
  @override
  List<Object?> get props => const [];
}

final class AttemptReviewLoading extends AttemptReviewState {
  const AttemptReviewLoading();
}

final class AttemptReviewLoaded extends AttemptReviewState {
  const AttemptReviewLoaded(this.review);
  final AttemptReview review;
  @override
  List<Object?> get props => [review];
}

final class AttemptReviewFailed extends AttemptReviewState {
  const AttemptReviewFailed(this.error);
  final AppError error;
  @override
  List<Object?> get props => [error];
}
