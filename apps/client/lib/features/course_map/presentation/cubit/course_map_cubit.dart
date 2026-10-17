import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/course_map/domain/repositories/course_map_repository.dart';
import 'package:sat_east_client/features/course_map/presentation/cubit/course_map_state.dart';

class CourseMapCubit extends Cubit<CourseMapState> {
  CourseMapCubit(this._repository) : super(const CourseMapLoading());

  final CourseMapRepository _repository;

  Future<void> load() async {
    emit(const CourseMapLoading());
    final result = await _repository.getCourseMap();
    if (isClosed) return;
    switch (result) {
      case Success(:final value):
        emit(CourseMapLoaded(value));
      case Failure(:final error):
        emit(CourseMapFailed(error));
    }
  }

  Future<void> retry() => load();
}
