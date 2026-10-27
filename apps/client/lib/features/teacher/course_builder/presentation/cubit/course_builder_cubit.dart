import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/teacher/course_builder/domain/entities/course_tree.dart';
import 'package:sat_east_client/features/teacher/course_builder/domain/entities/node_kind.dart';
import 'package:sat_east_client/features/teacher/course_builder/domain/repositories/course_builder_repository.dart';
import 'package:sat_east_client/features/teacher/course_builder/presentation/cubit/course_builder_state.dart';

class CourseBuilderCubit extends Cubit<CourseBuilderState> {
  CourseBuilderCubit(this._repository) : super(const CourseBuilderLoading());
  final CourseBuilderRepository _repository;
  var _generation = 0;

  Future<void> load(String? courseId) async {
    if (isClosed) {
      return;
    }
    final generation = ++_generation;
    emit(const CourseBuilderLoading());
    final courses = await _repository.listCourses();
    if (isClosed || generation != _generation) {
      return;
    }
    switch (courses) {
      case Failure(:final error):
        emit(CourseBuilderFailed(error));
      case Success(:final value):
        if (value.isEmpty) {
          emit(CourseBuilderLoaded(courses: value, tree: null));
          return;
        }
        final result = await _repository.getTree(courseId ?? value.first.id);
        if (isClosed || generation != _generation) {
          return;
        }
        switch (result) {
          case Failure(:final error):
            emit(CourseBuilderFailed(error));
          case Success(value: final tree):
            emit(CourseBuilderLoaded(courses: value, tree: tree));
        }
    }
  }

  Future<void> addUnit(String title) async {
    final current = _loaded;
    if (current == null) {
      return;
    }
    final courseId = current.tree!.courseId;
    await _mutate(
      courseId,
      () => _repository.upsertUnit(courseId: courseId, title: title),
    );
  }

  Future<void> addTopic(String unitId, String title) => _mutate(
    unitId,
    () => _repository.upsertTopic(unitId: unitId, title: title),
  );
  Future<void> addSubtopic(String topicId, String title) => _mutate(
    topicId,
    () => _repository.upsertSubtopic(topicId: topicId, title: title),
  );
  Future<void> rename(NodeKind kind, String id, String title) async {
    final current = _loaded;
    if (current == null) {
      return;
    }
    final parent = current.tree!.parentOf(kind, id);
    if (parent == null) {
      _invalid(current);
      return;
    }
    await _mutate(
      id,
      () => switch (kind) {
        NodeKind.unit => _repository.upsertUnit(
          id: id,
          courseId: parent,
          title: title,
        ),
        NodeKind.topic => _repository.upsertTopic(
          id: id,
          unitId: parent,
          title: title,
        ),
        NodeKind.subtopic => _repository.upsertSubtopic(
          id: id,
          topicId: parent,
          title: title,
        ),
      },
    );
  }

  Future<void> reorder(NodeKind kind, String parentId, List<String> ids) async {
    final current = _loaded;
    if (current == null) {
      return;
    }
    final optimistic = current.tree!.reordered(kind, parentId, ids);
    if (optimistic == null) {
      _invalid(current);
      return;
    }
    await _mutate(
      parentId,
      () => _repository.reorder(kind, parentId, ids),
      optimistic: optimistic,
    );
  }

  Future<void> delete(NodeKind kind, String id) =>
      _mutate(id, () => _repository.delete(kind, id));
  Future<void> setFlags(
    String topicId, {
    bool? isPublished,
    bool? isFreePreview,
  }) => _mutate(
    topicId,
    () => _repository.setFlags(
      topicId,
      isPublished: isPublished,
      isFreePreview: isFreePreview,
    ),
  );

  CourseBuilderLoaded? get _loaded => switch (state) {
    CourseBuilderLoaded(:final tree, busyId: null)
        when tree != null && !isClosed =>
      state as CourseBuilderLoaded,
    _ => null,
  };

  void _invalid(CourseBuilderLoaded current) => emit(
    CourseBuilderLoaded(
      courses: current.courses,
      tree: current.tree,
      lastError: const AppError(ErrorCodes.invalidInput),
    ),
  );

  Future<void> _mutate<T>(
    String busyId,
    Future<Result<T>> Function() write, {
    CourseTree? optimistic,
  }) async {
    final current = _loaded;
    if (current == null) {
      return;
    }
    final generation = _generation;
    emit(
      CourseBuilderLoaded(
        courses: current.courses,
        tree: optimistic ?? current.tree,
        busyId: busyId,
      ),
    );
    final result = await write();
    if (isClosed || generation != _generation) {
      return;
    }
    if (result case Failure(:final error)) {
      emit(
        CourseBuilderLoaded(
          courses: current.courses,
          tree: current.tree,
          lastError: error,
        ),
      );
      return;
    }
    final refreshed = await _repository.getTree(current.tree!.courseId);
    if (isClosed || generation != _generation) {
      return;
    }
    switch (refreshed) {
      case Success(:final value):
        emit(CourseBuilderLoaded(courses: current.courses, tree: value));
      case Failure(:final error):
        emit(
          CourseBuilderLoaded(
            courses: current.courses,
            tree: optimistic ?? current.tree,
            lastError: error,
          ),
        );
    }
  }
}
