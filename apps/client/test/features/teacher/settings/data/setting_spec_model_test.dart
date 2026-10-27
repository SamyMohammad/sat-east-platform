import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/features/teacher/settings/data/models/setting_spec_model.dart';

import '../settings_fixtures.dart';

void main() {
  test('ADM-06: parses all server-owned metadata and integer value', () {
    final spec = settingSpecFromJson(settingsJson.first);
    expect(spec.key, 'pass_mark');
    expect(spec.group, 'Quiz');
    expect(spec.label, 'Pass mark');
    expect(spec.unit, '%');
    expect(spec.min, 7);
    expect(spec.max, 93);
    expect(spec.value, 75);
    expect(spec.accepts(6), isFalse);
    expect(spec.accepts(7), isTrue);
    expect(spec.accepts(93), isTrue);
    expect(spec.accepts(94), isFalse);
    expect(spec.accepts(null), isFalse);
  });
  test('ADM-06: integral JSON decimals parse as integers', () {
    expect(
      settingSpecFromJson({...settingsJson.first, 'value': 75.0}).value,
      75,
    );
  });
  for (final change in <Map<String, Object?>>[
    {'key': null},
    {'group': 12},
    {'label': ''},
    {'unit': false},
    {'min': 7.5},
    {'max': null},
    {'value': 75.5},
    {'value': '75'},
    {'value': null},
    {'min': 100, 'max': 1},
  ]) {
    test('ADM-06: malformed metadata fails $change', () {
      expect(
        () => settingSpecFromJson({...settingsJson.first, ...change}),
        throwsFormatException,
      );
    });
  }
}
