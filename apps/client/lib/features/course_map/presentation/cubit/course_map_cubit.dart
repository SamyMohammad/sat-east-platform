import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/course_map/domain/entities/course_map.dart';
import 'package:sat_east_client/features/course_map/domain/repositories/course_map_repository.dart';
import 'package:sat_east_client/features/course_map/presentation/cubit/course_map_state.dart';

class CourseMapCubit extends Cubit<CourseMapState> {
  CourseMapCubit(this._repository) : super(const CourseMapLoading());

  final CourseMapRepository _repository;

  int _loadVersion = 0;
  CourseMap? _previous;

  Future<void> load() async {
    if (isClosed) return;
    final version = ++_loadVersion;
    if (state is! CourseMapLoaded) emit(const CourseMapLoading());
    final result = await _repository.getCourseMap();
    if (isClosed || version != _loadVersion) return;
    switch (result) {
      case Success(:final value):
        final previous = _previous;
        final locked = previous?.courseId == value.courseId
            ? {
                for (final unit in previous!.units)
                  for (final topic in unit.topics)
                    if (topic.status == TopicStatus.locked) topic.id,
              }
            : <String>{};
        final unlocked = {
          for (final unit in value.units)
            for (final topic in unit.topics)
              if (topic.status == TopicStatus.open && locked.contains(topic.id))
                topic.id,
        };
        _previous = value;
        emit(CourseMapLoaded(value, justUnlocked: Set.unmodifiable(unlocked)));
      case Failure(:final error):
        emit(CourseMapFailed(error));
    }
  }

  void acknowledgeUnlock() {
    if (isClosed) return;
    final current = state;
    if (current is CourseMapLoaded && current.justUnlocked.isNotEmpty) {
      emit(CourseMapLoaded(current.map));
    }
  }

  Future<void> retry() => load();
}
