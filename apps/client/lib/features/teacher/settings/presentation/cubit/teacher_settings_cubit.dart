import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/teacher/settings/domain/repositories/teacher_settings_repository.dart';
import 'package:sat_east_client/features/teacher/settings/presentation/cubit/teacher_settings_state.dart';

class TeacherSettingsCubit extends Cubit<TeacherSettingsState> {
  TeacherSettingsCubit(
    this._repository, {
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now,
       super(const TeacherSettingsLoading());
  final TeacherSettingsRepository _repository;
  final DateTime Function() _now;
  var _generation = 0;

  Future<void> load() async {
    if (isClosed ||
        state is TeacherSettingsLoaded &&
            (state as TeacherSettingsLoaded).saving) {
      return;
    }
    final generation = ++_generation;
    emit(const TeacherSettingsLoading());
    final result = await _repository.load();
    if (isClosed || generation != _generation) return;
    switch (result) {
      case Success(:final value):
        emit(TeacherSettingsLoaded(specs: value));
      case Failure(:final error):
        emit(TeacherSettingsFailed(error));
    }
  }

  void edit(String key, int? value) {
    final current = _ready;
    if (current == null) return;
    final spec = current.specs.where((s) => s.key == key).firstOrNull;
    if (spec == null) {
      emit(
        TeacherSettingsLoaded(
          specs: current.specs,
          edits: current.edits,
          invalidKeys: current.invalidKeys,
          lastError: const AppError(ErrorCodes.invalidInput),
        ),
      );
      return;
    }
    final edits = Map<String, int?>.of(current.edits);
    if (value == spec.value) {
      edits.remove(key);
    } else {
      edits[key] = value;
    }
    final invalidKeys = {
      for (final spec in current.specs)
        if (edits.containsKey(spec.key) && !spec.accepts(edits[spec.key]))
          spec.key,
    };
    emit(
      TeacherSettingsLoaded(
        specs: current.specs,
        edits: edits,
        invalidKeys: invalidKeys,
      ),
    );
  }

  void discard() {
    final current = _ready;
    if (current != null) emit(TeacherSettingsLoaded(specs: current.specs));
  }

  Future<void> save() async {
    final current = _ready;
    if (current == null || !current.isDirty) return;
    if (!current.canSave) {
      emit(
        TeacherSettingsLoaded(
          specs: current.specs,
          edits: current.edits,
          invalidKeys: current.invalidKeys,
          lastError: const AppError(ErrorCodes.invalidInput),
        ),
      );
      return;
    }
    final generation = _generation;
    final changed = {
      for (final entry in current.edits.entries) entry.key: entry.value!,
    };
    emit(
      TeacherSettingsLoaded(
        specs: current.specs,
        edits: current.edits,
        saving: true,
      ),
    );
    final saved = await _repository.save(changed);
    if (isClosed || generation != _generation) return;
    if (saved case Failure(:final error)) {
      _failedSave(current, error);
      return;
    }
    final reloaded = await _repository.load();
    if (isClosed || generation != _generation) return;
    switch (reloaded) {
      case Success(:final value):
        emit(TeacherSettingsLoaded(specs: value, savedAt: _now()));
      case Failure(:final error):
        _failedSave(current, error);
    }
  }

  TeacherSettingsLoaded? get _ready => switch (state) {
    TeacherSettingsLoaded(saving: false) when !isClosed =>
      state as TeacherSettingsLoaded,
    _ => null,
  };
  void _failedSave(TeacherSettingsLoaded current, AppError error) => emit(
    TeacherSettingsLoaded(
      specs: current.specs,
      edits: current.edits,
      invalidKeys: current.invalidKeys,
      lastError: error,
    ),
  );
}
