import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/course_map/domain/repositories/course_map_repository.dart';
import 'package:sat_east_client/features/skills/domain/repositories/skills_repository.dart';
import 'package:sat_east_client/features/skills/presentation/cubit/skills_state.dart';

class SkillsCubit extends Cubit<SkillsState> {
  SkillsCubit(this._skills, this._courseMap) : super(const SkillsLoading());

  final SkillsRepository _skills;
  final CourseMapRepository _courseMap;

  String? _courseId;
  int _loadVersion = 0;

  /// Loads the skills of [courseId], or of the student's current course (the
  /// one the course map shows) when null.
  Future<void> load({String? courseId}) async {
    if (isClosed) return;
    final version = ++_loadVersion;
    // Loaded and empty content stays visible while it refreshes.
    if (state is SkillsFailed) emit(const SkillsLoading());
    var id = courseId ?? _courseId;
    if (id == null) {
      final course = await _courseMap.getCourseMap();
      if (isClosed || version != _loadVersion) return;
      switch (course) {
        case Success(:final value):
          id = value.courseId;
        case Failure(:final error):
          emit(SkillsFailed(error));
          return;
      }
    }
    _courseId = id;
    final result = await _skills.load(id);
    if (isClosed || version != _loadVersion) return;
    switch (result) {
      case Success(:final value):
        emit(
          value.summary.gradedAnswers == 0
              ? const SkillsEmpty()
              : SkillsLoaded(value, id),
        );
      case Failure(:final error):
        emit(SkillsFailed(error));
    }
  }

  Future<void> retry() => load();
}
