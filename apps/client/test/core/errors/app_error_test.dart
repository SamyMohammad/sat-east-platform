import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/errors/result.dart';

void main() {
  test('P1-2: AppError with equal code and message are equal', () {
    expect(const AppError('x', 'm'), const AppError('x', 'm'));
  });

  test('P1-2: equal AppErrors share a hashCode', () {
    expect(
      const AppError('x', 'm').hashCode,
      const AppError('x', 'm').hashCode,
    );
  });

  test('P1-2: AppError without a message equals another without', () {
    expect(const AppError('x'), const AppError('x'));
  });

  test('P1-2: a different code is not equal', () {
    expect(const AppError('x', 'm'), isNot(const AppError('y', 'm')));
  });

  test('P1-2: a different message is not equal', () {
    expect(const AppError('x', 'm'), isNot(const AppError('x', 'n')));
  });
}
