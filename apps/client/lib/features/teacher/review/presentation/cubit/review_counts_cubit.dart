import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/teacher/review/domain/entities/review.dart';
import 'package:sat_east_client/features/teacher/review/domain/usecases/review_actions.dart';

class ReviewCountsState extends Equatable {
  const ReviewCountsState({this.counts, this.loading = false, this.error});
  final ReviewCounts? counts;
  final bool loading;
  final AppError? error;
  @override
  List<Object?> get props => [counts, loading, error];
}

class ReviewCountsCubit extends Cubit<ReviewCountsState> {
  ReviewCountsCubit(this._actions) : super(const ReviewCountsState());
  final ReviewActions _actions;
  int _generation = 0;
  Future<void> refresh() async {
    if (isClosed) return;
    final generation = ++_generation;
    emit(ReviewCountsState(counts: state.counts, loading: true));
    final response = await _actions.counts();
    if (isClosed || generation != _generation) return;
    switch (response) {
      case Success(:final value):
        emit(ReviewCountsState(counts: value));
      case Failure(:final error):
        emit(ReviewCountsState(counts: state.counts, error: error));
    }
  }
}
