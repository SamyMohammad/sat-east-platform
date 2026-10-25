import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/attempt_review/domain/repositories/attempt_review_repository.dart';
import 'package:sat_east_client/features/attempt_review/presentation/cubit/attempt_review_state.dart';

class AttemptReviewCubit extends Cubit<AttemptReviewState> {
  AttemptReviewCubit(this._repository) : super(const AttemptReviewLoading());
  final AttemptReviewRepository _repository;
  int _generation = 0;
  Future<void> load(String attemptId) async {
    if (isClosed) return;
    final generation = ++_generation;
    emit(const AttemptReviewLoading());
    final result = await _repository.load(attemptId);
    if (isClosed || generation != _generation) return;
    emit(switch (result) {
      Success(:final value) => AttemptReviewLoaded(value),
      Failure(:final error) => AttemptReviewFailed(error),
    });
  }
}
