import 'package:equatable/equatable.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/course_map/domain/entities/course_map.dart';

sealed class CourseMapState extends Equatable {
  const CourseMapState();

  @override
  List<Object?> get props => const [];
}

final class CourseMapLoading extends CourseMapState {
  const CourseMapLoading();
}

final class CourseMapLoaded extends CourseMapState {
  const CourseMapLoaded(this.map);

  final CourseMap map;

  @override
  List<Object?> get props => [map];
}

final class CourseMapFailed extends CourseMapState {
  const CourseMapFailed(this.error);

  final AppError error;

  @override
  List<Object?> get props => [error];
}
