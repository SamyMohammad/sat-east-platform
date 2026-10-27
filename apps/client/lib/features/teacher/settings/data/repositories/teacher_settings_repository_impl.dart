import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/teacher/settings/data/datasources/teacher_settings_remote_data_source.dart';
import 'package:sat_east_client/features/teacher/settings/domain/entities/setting_spec.dart';
import 'package:sat_east_client/features/teacher/settings/domain/repositories/teacher_settings_repository.dart';

class TeacherSettingsRepositoryImpl implements TeacherSettingsRepository {
  TeacherSettingsRepositoryImpl(this._remote);
  final TeacherSettingsRemoteDataSource _remote;
  @override
  Future<Result<List<SettingSpec>>> load() => _remote.load();
  @override
  Future<Result<void>> save(Map<String, int> changed) => _remote.save(changed);
}
