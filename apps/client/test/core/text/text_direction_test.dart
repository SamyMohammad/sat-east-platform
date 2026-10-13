import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/text/text_direction.dart';

void main() {
  test('F-4: English text is LTR', () {
    expect(detectTextDirection('Solve for x'), TextDirection.ltr);
  });
  test('F-4: Arabic text is RTL', () {
    expect(detectTextDirection('لدينا المعادلة'), TextDirection.rtl);
  });
  test('F-4: first strong letter decides (digits and symbols skipped)', () {
    expect(detectTextDirection('12 + لدينا x'), TextDirection.rtl);
    expect(detectTextDirection('(3) Then لدينا'), TextDirection.ltr);
  });
  test('F-4: no strong letter falls back', () {
    expect(detectTextDirection('123 = 4'), TextDirection.ltr);
    expect(
      detectTextDirection('', fallback: TextDirection.rtl),
      TextDirection.rtl,
    );
  });
}
