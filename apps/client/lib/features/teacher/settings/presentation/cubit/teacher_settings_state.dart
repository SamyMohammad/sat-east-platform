import 'package:equatable/equatable.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/teacher/settings/domain/entities/setting_spec.dart';

sealed class TeacherSettingsState extends Equatable {
  const TeacherSettingsState();
  @override
  List<Object?> get props => const [];
}

final class TeacherSettingsLoading extends TeacherSettingsState {
  const TeacherSettingsLoading();
}

final class TeacherSettingsLoaded extends TeacherSettingsState {
  TeacherSettingsLoaded({
    required List<SettingSpec> specs,
    Map<String, int?> edits = const {},
    Set<String> invalidKeys = const {},
    this.saving = false,
    this.lastError,
    this.savedAt,
  }) : specs = List.unmodifiable(specs),
       edits = Map.unmodifiable(edits),
       invalidKeys = Set.unmodifiable(invalidKeys);
  final List<SettingSpec> specs;
  final Map<String, int?> edits;
  final Set<String> invalidKeys;
  final bool saving;
  final AppError? lastError;
  final DateTime? savedAt;
  bool get isDirty => edits.isNotEmpty;
  bool get canSave => isDirty && invalidKeys.isEmpty && !saving;
  @override
  List<Object?> get props => [
    specs,
    edits,
    invalidKeys,
    saving,
    lastError,
    savedAt,
  ];
}

final class TeacherSettingsFailed extends TeacherSettingsState {
  const TeacherSettingsFailed(this.error);
  final AppError error;
  @override
  List<Object?> get props => [error];
}
