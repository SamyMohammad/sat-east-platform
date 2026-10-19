import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/features/catalogue/domain/entities/price.dart';
import 'package:sat_east_client/features/catalogue/presentation/price_format.dart';

void main() {
  for (final (currency, amount, expected) in [
    ('EGP', 240000, 'EGP 2,400'),
    ('USD', 1999, 'USD 19.99'),
    ('USD', 1905, 'USD 19.05'),
    ('USD', 0, 'USD 0'),
    ('EGP', 123456789, 'EGP 1,234,567.89'),
  ]) {
    test('PAY-01: formats $amount $currency', () {
      expect(
        formatPrice(Price(currency: currency, amountMinor: amount)),
        expected,
      );
    });
  }
}
