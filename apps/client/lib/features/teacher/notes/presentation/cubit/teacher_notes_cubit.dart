import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/teacher/notes/domain/entities/teacher_note.dart';
import 'package:sat_east_client/features/teacher/notes/domain/usecases/teacher_notes_actions.dart';
import 'package:sat_east_client/features/teacher/notes/presentation/cubit/teacher_notes_state.dart';
import 'package:sat_east_client/features/teacher/questions/domain/services/file_picker_service.dart';

class TeacherNotesCubit extends Cubit<TeacherNotesState> {
  TeacherNotesCubit(this._actions) : super(const TeacherNotesLoading());
  final TeacherNotesActions _actions;
  late String _topicId;
  int _generation = 0;
  Future<void> load(String topicId) async {
    if (isClosed ||
        (state is TeacherNotesReady && (state as TeacherNotesReady).busy)) {
      return;
    }
    _topicId = topicId;
    final generation = ++_generation;
    emit(const TeacherNotesLoading());
    final result = await _actions.load(topicId);
    if (isClosed || generation != _generation) return;
    emit(switch (result) {
      Success(:final value) => TeacherNotesReady(value),
      Failure(:final error) => TeacherNotesFailed(error),
    });
  }

  Future<void> pickAndUpload() async {
    final current = state;
    if (current is! TeacherNotesReady || current.busy || isClosed) return;
    emit(TeacherNotesReady(current.data, busy: true));
    final picked = await _actions.pickPdf();
    if (isClosed) return;
    if (picked case Failure(:final error)) {
      emit(
        TeacherNotesReady(
          current.data,
          error: error.code == ErrorCodes.cancelled ? null : error,
        ),
      );
      return;
    }
    await _complete(
      current,
      () => _actions.upload(
        _topicId,
        (picked as Success<PickedPdf>).value,
        current.data.maxMb,
      ),
    );
  }

  Future<void> upload(PickedPdf file) =>
      _mutate((data) => _actions.upload(_topicId, file, data.maxMb));
  Future<void> rename(TeacherNote note, String title) =>
      _mutate((_) => _actions.rename(note, title));
  Future<void> setSubtopic(TeacherNote note, String? id) =>
      _mutate((data) => _actions.setSubtopic(note, id, data.subtopics));
  Future<void> delete(TeacherNote note) =>
      _mutate((_) => _actions.delete(_topicId, note));
  Future<void> move(String id, int offset) async {
    final current = state;
    if (current is! TeacherNotesReady || current.busy || isClosed) return;
    final ids = current.data.movedIds(id, offset);
    if (ids == null) return;
    await _mutate((_) => _actions.reorder(_topicId, ids));
  }

  Future<void> _mutate(
    Future<Result<void>> Function(TeacherNotesData) action,
  ) async {
    final current = state;
    if (current is! TeacherNotesReady || current.busy || isClosed) return;
    emit(TeacherNotesReady(current.data, busy: true));
    await _complete(current, () => action(current.data));
  }

  Future<void> _complete(
    TeacherNotesReady current,
    Future<Result<void>> Function() action,
  ) async {
    final result = await action();
    if (isClosed) return;
    if (result case Failure(:final error)) {
      emit(TeacherNotesReady(current.data, error: error));
      return;
    }
    final notes = await _actions.list(_topicId);
    if (isClosed) return;
    emit(switch (notes) {
      Success(:final value) => TeacherNotesReady(current.data.withNotes(value)),
      Failure(:final error) => TeacherNotesReady(current.data, error: error),
    });
  }
}
