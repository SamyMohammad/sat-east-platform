import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/mock/domain/entities/mock_entities.dart';
import 'package:sat_east_client/features/mock/domain/repositories/mock_repository.dart';
import 'package:sat_east_client/features/mock/presentation/cubit/mock_hub_state.dart';

class MockHubCubit extends Cubit<MockHubState> {
  MockHubCubit(this._repository) : super(const MockHubLoading());

  final MockRepository _repository;

  /// Loads the SAT course and its hub. A reload over a loaded hub keeps it on
  /// screen and records a failure in `lastError`.
  Future<void> load() async {
    final before = state;
    if (before is! MockHubLoaded) emit(const MockHubLoading());
    final course = await _repository.satCourseId();
    if (isClosed) return;
    switch (course) {
      case Failure(:final error):
        _fail(error);
      case Success(value: null):
        emit(const MockHubNoCourse());
      case Success(:final value?):
        final hub = await _repository.hub(value);
        if (isClosed) return;
        switch (hub) {
          case Failure(:final error):
            _fail(error);
          case Success(value: final hub):
            emit(MockHubLoaded(courseId: value, hub: hub));
        }
    }
  }

  void _fail(AppError error) {
    final current = state;
    emit(
      current is MockHubLoaded
          ? current.copyWith(lastError: error)
          : MockHubFailed(error),
    );
  }

  Future<void> retry() => load();

  /// Starts the lowest available form or resumes the unfinished one. Returns
  /// the stage so the screen can open the exam; null on an error (kept in
  /// `lastError`) or while another start is running.
  Future<MockStage?> start() async {
    final current = state;
    if (current is! MockHubLoaded || current.busy) return null;
    emit(current.copyWith(busy: true));
    final result = await _repository.start(current.courseId);
    if (isClosed) return null;
    switch (result) {
      case Failure(:final error):
        emit(current.copyWith(busy: false, lastError: error));
        return null;
      case Success(:final value):
        emit(current.copyWith(busy: false));
        return value;
    }
  }
}
