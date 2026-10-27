import 'package:equatable/equatable.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/teacher/notes/domain/entities/teacher_note.dart';

sealed class TeacherNotesState extends Equatable {
  const TeacherNotesState();
  @override
  List<Object?> get props => [];
}

final class TeacherNotesLoading extends TeacherNotesState {
  const TeacherNotesLoading();
}

final class TeacherNotesFailed extends TeacherNotesState {
  const TeacherNotesFailed(this.error);
  final AppError error;
  @override
  List<Object?> get props => [error];
}

final class TeacherNotesReady extends TeacherNotesState {
  const TeacherNotesReady(this.data, {this.busy = false, this.error});
  final TeacherNotesData data;
  final bool busy;
  final AppError? error;
  @override
  List<Object?> get props => [data, busy, error];
}
