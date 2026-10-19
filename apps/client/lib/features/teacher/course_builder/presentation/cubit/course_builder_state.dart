import 'package:equatable/equatable.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/teacher/course_builder/domain/entities/course_tree.dart';

sealed class CourseBuilderState extends Equatable {
  const CourseBuilderState();
  @override
  List<Object?> get props => const [];
}

final class CourseBuilderLoading extends CourseBuilderState {
  const CourseBuilderLoading();
}

final class CourseBuilderLoaded extends CourseBuilderState {
  CourseBuilderLoaded({
    required List<TeacherCourse> courses,
    required this.tree,
    this.busyId,
    this.lastError,
  }) : courses = List.unmodifiable(courses);
  final List<TeacherCourse> courses;
  final CourseTree? tree;
  final String? busyId;
  final AppError? lastError;
  @override
  List<Object?> get props => [courses, tree, busyId, lastError];
}

final class CourseBuilderFailed extends CourseBuilderState {
  const CourseBuilderFailed(this.error);
  final AppError error;
  @override
  List<Object?> get props => [error];
}
