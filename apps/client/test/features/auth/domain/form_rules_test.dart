import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/features/auth/domain/form_rules.dart';

void main() {
  group('P3-3: FormRules.passwordRules mirrors the server policy', () {
    test('P3-3: the minimum length is 8', () {
      expect(FormRules.minPasswordLength, 8);
    });

    test('P3-3: 8 characters with a letter and a digit pass', () {
      expect(FormRules.passwordRules('abcdefg1').allMet, isTrue);
    });

    test('P3-3: 7 characters fail on length', () {
      final rules = FormRules.passwordRules('abcdef1');
      expect(rules.hasMinLength, isFalse);
      expect(rules.allMet, isFalse);
    });

    test('P3-3: letters only fail on the number rule', () {
      final rules = FormRules.passwordRules('abcdefgh');
      expect(rules.hasNumber, isFalse);
      expect(rules.allMet, isFalse);
    });

    test('P3-3: digits only fail on the letter rule', () {
      final rules = FormRules.passwordRules('12345678');
      expect(rules.hasLetter, isFalse);
      expect(rules.allMet, isFalse);
    });
  });
}
