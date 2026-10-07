import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/grading/spr_answer.dart';

// Shared with the SQL grader (docs/08 §6). flutter test runs from apps/client.
const _fixture = '../../supabase/tests/fixtures/spr_cases.json';
const _sqlTest = '../../supabase/tests/12_spr_grader.test.sql';

void main() {
  final cases = (jsonDecode(File(_fixture).readAsStringSync()) as List<dynamic>)
      .cast<Map<String, dynamic>>();

  group('GRD-02: parseSprAnswer matches the shared fixture', () {
    for (final c in cases) {
      final input = c['input'] as String;
      final invalid = c['expected'] == 'invalid';
      test('GRD-02: "$input" is ${invalid ? 'invalid' : 'valid'}', () {
        expect(parseSprAnswer(input) is SprInvalid, invalid);
      });
    }
  });

  test('GRD-02: values are reduced rationals', () {
    final answer = parseSprAnswer('-2/4');
    expect(answer, isA<SprValid>());
    final valid = answer as SprValid;
    expect(valid.numerator, BigInt.from(-1));
    expect(valid.denominator, BigInt.two);
  });

  test('GRD-02: decimals become exact fractions', () {
    final valid = parseSprAnswer('.75') as SprValid;
    expect(valid.numerator, BigInt.from(3));
    expect(valid.denominator, BigInt.from(4));
  });

  test('GRD-02: reasons for invalid input', () {
    SprInvalidReason reason(String s) =>
        (parseSprAnswer(s) as SprInvalid).reason;
    expect(reason('   '), SprInvalidReason.empty);
    expect(reason('100000'), SprInvalidReason.tooLong);
    expect(reason('3 1/2'), SprInvalidReason.mixedNumber);
    expect(reason('1/0'), SprInvalidReason.zeroDenominator);
    expect(reason('5%'), SprInvalidReason.format);
  });

  test('GRD-02: the SQL test embeds the same fixture', () {
    final sql = File(_sqlTest).readAsStringSync();
    final embedded = sql.split(r'$json$')[1];
    expect(jsonDecode(embedded), jsonDecode(File(_fixture).readAsStringSync()));
  });
}
