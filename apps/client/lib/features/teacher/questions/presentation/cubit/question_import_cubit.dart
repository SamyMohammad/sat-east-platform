import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/teacher/questions/domain/entities/picked_file.dart';
import 'package:sat_east_client/features/teacher/questions/domain/repositories/question_import_repository.dart';
import 'package:sat_east_client/features/teacher/questions/domain/services/file_picker_service.dart';
import 'package:sat_east_client/features/teacher/questions/domain/services/parse_import_file.dart';
import 'package:sat_east_client/features/teacher/questions/presentation/cubit/question_import_state.dart';

class QuestionImportCubit extends Cubit<QuestionImportState> {
  QuestionImportCubit(this._repository, this._picker)
    : super(const ImportIdle());
  final QuestionImportRepository _repository;
  final FilePickerService _picker;
  List<Object?>? _items;
  PickedFile? _file;
  var _generation = 0;
  bool get _busy =>
      state is ImportReading ||
      state is ImportValidating ||
      state is ImportCommitting;
  Future<void> pick() async {
    if (isClosed || _busy) return;
    final previous = state;
    final generation = ++_generation;
    emit(const ImportReading());
    final picked = await _picker.pickJson();
    if (isClosed || generation != _generation) return;
    switch (picked) {
      case Failure(:final error):
        emit(
          error.code == ErrorCodes.cancelled ? previous : ImportFailed(error),
        );
      case Success(:final value):
        final parsed = parseImportFile(value.text);
        switch (parsed) {
          case Failure(:final error):
            _items = null;
            _file = null;
            emit(ImportFailed(error));
          case Success(:final value):
            _items = value;
            _file = picked.value;
            await _validate(generation);
        }
    }
  }

  Future<void> validate() async {
    if (isClosed || _busy || _items == null || _file == null) return;
    await _validate(++_generation);
  }

  Future<void> _validate(int generation) async {
    emit(ImportValidating(_file!));
    final result = await _repository.dryRun(_items!);
    if (isClosed || generation != _generation) return;
    switch (result) {
      case Success(:final value):
        emit(ImportReported(_file!, value));
      case Failure(:final error):
        emit(ImportFailed(error));
    }
  }

  Future<void> commit() async {
    if (isClosed || state is! ImportReported || _items == null) return;
    final reported = state as ImportReported;
    if (!reported.report.canCommit) return;
    final generation = ++_generation;
    emit(const ImportCommitting());
    final result = await _repository.commit(_items!);
    if (isClosed || generation != _generation) return;
    switch (result) {
      case Success(:final value):
        if (value.canCommit) {
          emit(ImportCommitted(value));
        } else {
          emit(ImportReported(_file!, value));
        }
      case Failure(:final error):
        emit(ImportFailed(error));
    }
  }

  void reset() {
    if (isClosed) return;
    _generation++;
    _items = null;
    _file = null;
    emit(const ImportIdle());
  }
}
