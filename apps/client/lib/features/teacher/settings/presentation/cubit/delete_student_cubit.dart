import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/teacher/settings/domain/repositories/teacher_settings_repository.dart';
import 'package:sat_east_client/features/teacher/settings/presentation/cubit/delete_student_state.dart';

/// Teacher-only hard delete of a student by email (P3.7). The server decides
/// everything; this only guards double taps and blank input.
class DeleteStudentCubit extends Cubit<DeleteStudentState> {
  DeleteStudentCubit(this._repository) : super(const DeleteStudentIdle());
  final TeacherSettingsRepository _repository;

  /// Whether [typed] repeats [email] (both trimmed); gates the confirm button.
  static bool confirmationMatches(String email, String typed) {
    final target = email.trim();
    return target.isNotEmpty && target == typed.trim();
  }

  Future<void> delete(String email) async {
    if (isClosed || state is DeleteStudentInProgress) return;
    final target = email.trim();
    if (target.isEmpty) {
      emit(const DeleteStudentFailed(AppError(ErrorCodes.invalidInput)));
      return;
    }
    emit(const DeleteStudentInProgress());
    final result = await _repository.deleteStudent(target);
    if (isClosed) return;
    switch (result) {
      case Success():
        emit(DeleteStudentDone(target));
      case Failure(:final error):
        emit(DeleteStudentFailed(error));
    }
  }

  void reset() {
    if (!isClosed && state is! DeleteStudentInProgress) {
      emit(const DeleteStudentIdle());
    }
  }
}
