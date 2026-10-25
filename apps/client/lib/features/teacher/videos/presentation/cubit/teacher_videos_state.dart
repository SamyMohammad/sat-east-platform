import 'package:equatable/equatable.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/teacher/videos/domain/entities/teacher_video.dart';

sealed class TeacherVideosState extends Equatable {
  const TeacherVideosState();
  @override
  List<Object?> get props => [];
}

final class TeacherVideosLoading extends TeacherVideosState {
  const TeacherVideosLoading();
}

final class TeacherVideosFailed extends TeacherVideosState {
  const TeacherVideosFailed(this.error);
  final AppError error;
  @override
  List<Object?> get props => [error];
}

final class TeacherVideosReady extends TeacherVideosState {
  const TeacherVideosReady(this.data, {this.busy = false, this.error});
  final TeacherVideosData data;
  final bool busy;
  final AppError? error;
  @override
  List<Object?> get props => [data, busy, error];
}
