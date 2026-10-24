import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/teacher/review/domain/entities/review.dart';
import 'package:sat_east_client/features/teacher/review/domain/usecases/review_actions.dart';

class ReviewReportsState extends Equatable {
  ReviewReportsState({
    List<QuestionReport> reports = const [],
    this.loading = false,
    this.resolving = false,
    this.error,
    this.resolved = 0,
  }) : reports = List.unmodifiable(reports);
  final List<QuestionReport> reports;
  final bool loading;
  final bool resolving;
  final AppError? error;
  final int resolved;
  @override
  bool get stringify => false;
  @override
  List<Object?> get props => [reports, loading, resolving, error, resolved];
}

class ReviewReportsCubit extends Cubit<ReviewReportsState> {
  ReviewReportsCubit(this._actions) : super(ReviewReportsState());
  final ReviewActions _actions;
  String? _questionId;
  int _generation = 0;
  Future<void> load(String id) async {
    if (isClosed) return;
    final previous = _questionId == id
        ? state.reports
        : const <QuestionReport>[];
    _questionId = id;
    final generation = ++_generation;
    emit(
      ReviewReportsState(
        reports: previous,
        loading: true,
        resolved: state.resolved,
      ),
    );
    final response = await _actions.reports(id);
    if (isClosed || generation != _generation) return;
    switch (response) {
      case Success(:final value):
        emit(ReviewReportsState(reports: value, resolved: state.resolved));
      case Failure(:final error):
        emit(
          ReviewReportsState(
            reports: previous,
            error: error,
            resolved: state.resolved,
          ),
        );
    }
  }

  Future<void> retry() async {
    if (_questionId case final id?) await load(id);
  }

  Future<void> resolve(String outcome, String? note) async {
    final id = _questionId;
    if (isClosed || id == null || state.resolving || state.loading) return;
    final generation = _generation;
    emit(
      ReviewReportsState(
        reports: state.reports,
        resolving: true,
        resolved: state.resolved,
      ),
    );
    final response = await _actions.resolve(id, outcome, note);
    if (isClosed || generation != _generation) return;
    switch (response) {
      case Success():
        emit(ReviewReportsState(resolved: state.resolved + 1));
        await load(id);
      case Failure(:final error):
        emit(
          ReviewReportsState(
            reports: state.reports,
            error: error,
            resolved: state.resolved,
          ),
        );
    }
  }
}
