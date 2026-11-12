import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/teacher/mock/domain/entities/mock_entities.dart';
import 'package:sat_east_client/features/teacher/mock/domain/repositories/teacher_mock_repository.dart';
import 'package:sat_east_client/features/teacher/mock/domain/usecases/find_sat_course.dart';
import 'package:sat_east_client/features/teacher/mock/presentation/cubit/mock_form_state.dart';
import 'package:sat_east_client/features/teacher/mock/presentation/mock_copy.dart';
import 'package:sat_east_client/features/teacher/questions/domain/repositories/question_editor_repository.dart';

class MockFormCubit extends Cubit<MockFormState> {
  MockFormCubit(
    this._mock,
    this._editor,
    this._findSatCourse, {
    required this.setNo,
    required this.formNo,
  }) : super(const MockFormLoading());
  final TeacherMockRepository _mock;
  final QuestionEditorRepository _editor;
  final FindSatCourse _findSatCourse;
  final int setNo;
  final int formNo;
  late String _courseId;

  Future<void> load() async {
    if (state is! MockFormLoaded) emit(const MockFormLoading());
    final course = await _findSatCourse();
    if (isClosed) return;
    switch (course) {
      case Failure(:final error):
        emit(MockFormFailed(error));
      case Success(value: null):
        emit(const MockFormMissing());
      case Success(:final value?):
        _courseId = value.id;
        await _loadForm();
    }
  }

  /// Fetches the form; keeps the loaded state (and its stale marks) on a
  /// refresh and maps a vanished form to [MockFormMissing].
  Future<void> _loadForm() async {
    final result = await _mock.form(_courseId, setNo, formNo);
    if (isClosed) return;
    final current = state;
    switch (result) {
      case Failure(:final error) when error.code == ErrorCodes.invalidInput:
        emit(const MockFormMissing());
      case Failure(:final error):
        emit(
          current is MockFormLoaded
              ? current.copyWith(busy: false, lastError: error)
              : MockFormFailed(error),
        );
      case Success(:final value):
        final ids = {
          for (final m in value.modules)
            for (final s in m.slots) s.questionId,
        };
        emit(
          current is MockFormLoaded
              ? current.copyWith(
                  form: value,
                  stale: current.stale.intersection(ids),
                  busy: false,
                  // The previewed question may have been swapped out.
                  previewId: ids.contains(current.previewId)
                      ? current.previewId
                      : null,
                  preview: ids.contains(current.previewId)
                      ? current.preview
                      : null,
                  previewError: ids.contains(current.previewId)
                      ? current.previewError
                      : null,
                )
              : MockFormLoaded(value),
        );
    }
  }

  Future<void> openPreview(String id) async {
    final current = state;
    if (current is! MockFormLoaded) return;
    emit(current.copyWith(previewId: id, preview: null, previewError: null));
    final result = await _editor.get(id);
    if (isClosed) return;
    final now = state;
    if (now is! MockFormLoaded || now.previewId != id) return;
    emit(switch (result) {
      Success(:final value) => now.copyWith(preview: value),
      Failure(:final error) => now.copyWith(previewError: error),
    });
  }

  void closePreview() {
    final current = state;
    if (current is! MockFormLoaded || current.previewId == null) return;
    emit(current.copyWith(previewId: null, preview: null, previewError: null));
  }

  /// Whether [openSwap] would start now (a draft that is not busy).
  bool get canOpenSwap {
    final current = state;
    return current is MockFormLoaded && current.isDraft && !current.busy;
  }

  /// Starts loading the slot's candidates; false when swapping is not
  /// possible right now, so the screen opens no sheet.
  Future<bool> openSwap(String questionId) async {
    if (!canOpenSwap) return false;
    final current = state as MockFormLoaded;
    emit(
      current.copyWith(
        swappingId: questionId,
        candidates: null,
        lastError: null,
      ),
    );
    final result = await _mock.candidates(
      _courseId,
      setNo,
      formNo,
      questionId,
    );
    if (isClosed) return true;
    final now = state;
    if (now is! MockFormLoaded || now.swappingId != questionId) return true;
    switch (result) {
      case Success(:final value):
        emit(now.copyWith(candidates: value));
      case Failure(:final error):
        emit(now.copyWith(swappingId: null, lastError: error));
        await _reloadIfGone(error);
    }
    return true;
  }

  void closeSwap() {
    final current = state;
    if (current is! MockFormLoaded || current.swappingId == null) return;
    emit(current.copyWith(swappingId: null, candidates: null));
  }

  /// Replaces the slot's question; true when the swap went through.
  Future<bool> swap(String newId) async {
    final current = state;
    final oldId = current is MockFormLoaded ? current.swappingId : null;
    if (current is! MockFormLoaded ||
        oldId == null ||
        !current.isDraft ||
        current.busy) {
      return false;
    }
    emit(current.copyWith(busy: true, lastError: null));
    final result = await _mock.swap(_courseId, setNo, formNo, oldId, newId);
    if (isClosed) return false;
    switch (result) {
      case Success():
        final now = state;
        if (now is MockFormLoaded) {
          emit(
            now.copyWith(
              stale: {...now.stale}..remove(oldId),
              swappingId: null,
              candidates: null,
            ),
          );
        }
        await _loadForm();
        return true;
      case Failure(:final error):
        await _fail(
          error.code == ErrorCodes.invalidInput
              ? const AppError(mockSlotUnavailableCode)
              : error,
        );
        return false;
    }
  }

  Future<void> publish() async {
    final current = state;
    if (current is! MockFormLoaded || !current.isDraft || current.busy) return;
    emit(current.copyWith(busy: true, lastError: null));
    final result = await _mock.publish(_courseId, setNo, formNo);
    if (isClosed) return;
    switch (result) {
      case Success(value: Published()):
        final now = state;
        if (now is MockFormLoaded) emit(now.copyWith(stale: const {}));
        await _loadForm();
      case Success(value: Stale(:final questionIds)):
        final now = state;
        if (now is MockFormLoaded) {
          emit(now.copyWith(stale: questionIds.toSet(), busy: false));
        }
      case Failure(:final error):
        await _fail(error);
    }
  }

  /// True when the draft is gone and the screen should leave.
  Future<bool> delete() async {
    final current = state;
    if (current is! MockFormLoaded || !current.isDraft || current.busy) {
      return false;
    }
    emit(current.copyWith(busy: true, lastError: null));
    final result = await _mock.deleteDraft(_courseId, setNo, formNo);
    if (isClosed) return false;
    switch (result) {
      case Success():
        return true;
      case Failure(:final error):
        await _fail(error);
        return false;
    }
  }

  /// Shows [error]; a published or vanished form is reloaded so the page
  /// shows what the server says now.
  Future<void> _fail(AppError error) async {
    final current = state;
    if (current is! MockFormLoaded) return;
    final reload = _isGone(error);
    emit(
      current.copyWith(
        busy: false,
        lastError: error,
        swappingId: reload ? null : current.swappingId,
        candidates: reload ? null : current.candidates,
      ),
    );
    await _reloadIfGone(error);
  }

  Future<void> _reloadIfGone(AppError error) async {
    if (_isGone(error)) await _loadForm();
  }

  bool _isGone(AppError error) =>
      error.code == ErrorCodes.mockFormPublished ||
      error.code == ErrorCodes.invalidInput ||
      error.code == mockSlotUnavailableCode;
}
