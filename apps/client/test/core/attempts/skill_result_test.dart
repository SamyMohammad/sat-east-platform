import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/attempts/skill_result.dart';

void main() {
  const valid = {'code': 'ALG', 'name': 'Algebra', 'correct': 1, 'total': 3};
  test('ANL-02: skill_result_parses', () {
    expect(
      skillResultFromJson(valid),
      const SkillResult(
        code: 'ALG',
        name: 'Algebra',
        correct: 1,
        total: 3,
      ),
    );
    expect(skillResultFromJson({...valid, 'correct': 0}).correct, 0);
    expect(skillResultFromJson({...valid, 'correct': 3}).correct, 3);
  });
  final invalid = <Object?>[
    null,
    [],
    {},
    for (final field in ['code', 'name'])
      for (final value in [null, '', '  ', 1]) {...valid, field: value},
    for (final value in [null, -1, 1.5, 4, '1']) {...valid, 'correct': value},
    for (final value in [null, -1, 0, 1.5, '3']) {...valid, 'total': value},
  ];
  for (final (index, value) in invalid.indexed) {
    test('ANL-02: skill_result_rejects_invalid_$index', () {
      expect(() => skillResultFromJson(value), throwsFormatException);
    });
  }
}
