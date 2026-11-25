import 'package:equatable/equatable.dart';
import 'package:sat_east_client/core/errors/result.dart';

sealed class DeleteStudentState extends Equatable {
  const DeleteStudentState();
  @override
  List<Object?> get props => const [];
}

final class DeleteStudentIdle extends DeleteStudentState {
  const DeleteStudentIdle();
}

final class DeleteStudentInProgress extends DeleteStudentState {
  const DeleteStudentInProgress();
}

final class DeleteStudentDone extends DeleteStudentState {
  const DeleteStudentDone(this.email);
  final String email;
  @override
  List<Object?> get props => [email];
}

final class DeleteStudentFailed extends DeleteStudentState {
  const DeleteStudentFailed(this.error);
  final AppError error;
  @override
  List<Object?> get props => [error];
}
