import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/teacher/review/domain/entities/review.dart';
import 'package:sat_east_client/features/teacher/review/domain/usecases/review_actions.dart';

class ReviewQueueState extends Equatable {
  const ReviewQueueState({
    this.section = ReviewSection.reported,
    this.page = 1,
    this.result,
    this.loading = false,
    this.resolving = false,
    this.error,
    this.resolved = 0,
  });
  final ReviewSection section;
  final int page;
  final ReviewPage? result;
  final bool loading;
  final bool resolving;
  final AppError? error;
  final int resolved;
  @override
  bool get stringify => false;
  @override
  List<Object?> get props => [
    section,
    page,
    result,
    loading,
    resolving,
    error,
    resolved,
  ];
}

class ReviewQueueCubit extends Cubit<ReviewQueueState> {
  ReviewQueueCubit(this._actions) : super(const ReviewQueueState());
  final ReviewActions _actions;
  int _generation = 0;
  Future<void> load(ReviewSection section) => _load(section, 1);
  Future<void> next() async {
    if (!state.loading && state.result?.hasNext == true) {
      await _load(state.section, state.page + 1);
    }
  }

  Future<void> prev() async {
    if (!state.loading && state.page > 1) {
      await _load(state.section, state.page - 1);
    }
  }

  Future<void> retry() => _load(state.section, state.page);
  Future<void> _load(ReviewSection section, int page) async {
    if (isClosed) return;
    final generation = ++_generation;
    final previous = state.section == section && state.result?.page == page
        ? state.result
        : null;
    emit(
      ReviewQueueState(
        section: section,
        page: page,
        result: previous,
        loading: true,
        resolving: state.resolving,
        resolved: state.resolved,
      ),
    );
    final response = await _actions.list(section, page);
    if (isClosed || generation != _generation) return;
    switch (response) {
      case Success(:final value):
        emit(
          ReviewQueueState(
            section: section,
            page: page,
            result: value,
            resolved: state.resolved,
            resolving: state.resolving,
          ),
        );
      case Failure(:final error):
        emit(
          ReviewQueueState(
            section: section,
            page: page,
            result: previous,
            error: error,
            resolved: state.resolved,
            resolving: state.resolving,
          ),
        );
    }
  }

  Future<void> resolve(String id, String outcome, String? note) async {
    if (isClosed || state.resolving || state.loading) return;
    final generation = _generation;
    emit(
      ReviewQueueState(
        section: state.section,
        page: state.page,
        result: state.result,
        resolving: true,
        resolved: state.resolved,
      ),
    );
    final response = await _actions.resolve(id, outcome, note);
    if (isClosed) return;
    switch (response) {
      case Success():
        emit(
          ReviewQueueState(
            section: state.section,
            page: state.page,
            result: state.result,
            loading: state.loading,
            resolved: state.resolved + 1,
          ),
        );
        await retry();
      case Failure(:final error):
        emit(
          ReviewQueueState(
            section: state.section,
            page: state.page,
            result: state.result,
            loading: state.loading,
            error: generation == _generation ? error : state.error,
            resolved: state.resolved,
          ),
        );
    }
  }
}
