import 'package:equatable/equatable.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/catalogue/domain/entities/course_page.dart';

sealed class CoursePageState extends Equatable {
  const CoursePageState();

  @override
  List<Object?> get props => const [];
}

final class CoursePageLoading extends CoursePageState {
  const CoursePageLoading();
}

final class CoursePageLoaded extends CoursePageState {
  const CoursePageLoaded(this.data);

  final CoursePage data;

  @override
  List<Object?> get props => [data];
}

final class CoursePageFailed extends CoursePageState {
  const CoursePageFailed(this.error);

  final AppError error;

  @override
  List<Object?> get props => [error];
}
