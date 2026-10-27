import 'package:sat_east_client/features/teacher/settings/domain/entities/setting_spec.dart';

SettingSpec settingSpecFromJson(Map<String, Object?> json) {
  final min = _integer(json['min']);
  final max = _integer(json['max']);
  if (min > max) throw const FormatException('range');
  return SettingSpec(
    key: _string(json, 'key'),
    group: _string(json, 'group'),
    label: _string(json, 'label'),
    unit: _string(json, 'unit'),
    min: min,
    max: max,
    value: _integer(json['value']),
  );
}

String _string(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String || value.isEmpty) throw FormatException(key);
  return value;
}

int _integer(Object? value) {
  if (value is! num || !value.isFinite || value != value.truncateToDouble()) {
    throw const FormatException('integer');
  }
  return value.toInt();
}
