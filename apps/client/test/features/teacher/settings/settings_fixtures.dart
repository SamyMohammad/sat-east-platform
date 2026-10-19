import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/teacher/settings/data/models/setting_spec_model.dart';
import 'package:sat_east_client/features/teacher/settings/domain/entities/setting_spec.dart';
import 'package:sat_east_client/features/teacher/settings/domain/repositories/teacher_settings_repository.dart';

const List<Map<String, Object?>> settingsJson = [
  {
    'key': 'pass_mark',
    'group': 'Quiz',
    'label': 'Pass mark',
    'unit': '%',
    'min': 7,
    'max': 93,
    'value': 75,
  },
  {
    'key': 'homework_size',
    'group': 'Practice',
    'label': 'Homework size',
    'unit': 'questions',
    'min': 2,
    'max': 42,
    'value': 20,
  },
  {
    'key': 'access_min_days',
    'group': 'Access',
    'label': 'Minimum access',
    'unit': 'days',
    'min': 12,
    'max': 250,
    'value': 60,
  },
  {
    'key': 'device_limit',
    'group': 'Devices',
    'label': 'Devices per student',
    'unit': 'devices',
    'min': 1,
    'max': 4,
    'value': 2,
  },
  {
    'key': 'ai_daily_cap',
    'group': 'AI',
    'label': 'AI questions per day',
    'unit': 'per day',
    'min': 0,
    'max': 150,
    'value': 20,
  },
];
final List<SettingSpec> settingsSpecs = settingsJson
    .map(settingSpecFromJson)
    .toList();
final DateTime savedTime = DateTime.utc(2026, 10, 20, 12);

class FakeTeacherSettingsRepository implements TeacherSettingsRepository {
  Result<List<SettingSpec>> loadResult = Success(settingsSpecs);
  Result<void> saveResult = const Success(null);
  Future<Result<List<SettingSpec>>>? pendingLoad;
  Future<Result<void>>? pendingSave;
  void Function()? onLoad;
  int loads = 0;
  final List<Map<String, int>> saves = [];
  @override
  Future<Result<List<SettingSpec>>> load() {
    loads++;
    onLoad?.call();
    return pendingLoad ?? Future.value(loadResult);
  }

  @override
  Future<Result<void>> save(Map<String, int> changed) {
    saves.add(Map.of(changed));
    return pendingSave ?? Future.value(saveResult);
  }
}
