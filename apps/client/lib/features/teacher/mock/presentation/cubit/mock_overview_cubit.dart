import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/teacher/mock/domain/entities/mock_entities.dart';
import 'package:sat_east_client/features/teacher/mock/domain/repositories/teacher_mock_repository.dart';
import 'package:sat_east_client/features/teacher/mock/domain/usecases/find_sat_course.dart';
import 'package:sat_east_client/features/teacher/mock/presentation/cubit/mock_overview_state.dart';

class MockOverviewCubit extends Cubit<MockOverviewState> {
  MockOverviewCubit(this._mock, this._findSatCourse)
    : super(const MockOverviewLoading());
  final TeacherMockRepository _mock;
  final FindSatCourse _findSatCourse;

  Future<void> load() async {
    if (state is! MockOverviewLoaded) emit(const MockOverviewLoading());
    final course = await _findSatCourse();
    if (isClosed) return;
    switch (course) {
      case Failure(:final error):
        emit(MockOverviewFailed(error));
      case Success(value: null):
        emit(const MockOverviewNoCourse());
      case Success(:final value?):
        switch (await _mock.overview(value.id)) {
          case Failure(:final error):
            if (!isClosed) emit(MockOverviewFailed(error));
          case Success(value: final overview):
            if (!isClosed) {
              emit(MockOverviewLoaded(courseId: value.id, overview: overview));
            }
        }
    }
  }

  Future<void> retry() => load();

  /// Returns the new form so the screen can open it; null on a shortage or
  /// an error (both are kept in the state).
  Future<Assembled?> assemble(int setNo) async {
    final current = state;
    if (current is! MockOverviewLoaded || current.busy) return null;
    emit(current.copyWith(busy: true));
    final result = await _mock.assemble(current.courseId, setNo);
    if (isClosed) return null;
    switch (result) {
      case Failure(:final error):
        emit(current.copyWith(lastError: error));
        return null;
      case Success(value: final Assembled assembled):
        await _refresh(current.courseId);
        return assembled;
      case Success(value: final Shortage shortage):
        await _refresh(current.courseId, shortage: shortage);
        return null;
    }
  }

  /// Reloads the overview after an assemble; keeps the old one on failure.
  Future<void> _refresh(String courseId, {Shortage? shortage}) async {
    final result = await _mock.overview(courseId);
    if (isClosed) return;
    final current = state;
    if (current is! MockOverviewLoaded) return;
    emit(
      current.copyWith(
        overview: switch (result) {
          Success(:final value) => value,
          Failure() => null,
        },
        busy: false,
        lastShortage: shortage,
        lastError: switch (result) {
          Failure(:final error) => error,
          Success() => null,
        },
      ),
    );
  }
}
