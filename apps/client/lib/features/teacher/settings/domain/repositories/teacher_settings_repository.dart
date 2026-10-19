import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/teacher/settings/domain/entities/setting_spec.dart';

abstract interface class TeacherSettingsRepository {
  Future<Result<List<SettingSpec>>> load();
  Future<Result<void>> save(Map<String, int> changed);
}
