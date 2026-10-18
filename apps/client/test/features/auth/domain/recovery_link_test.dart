import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/features/auth/domain/recovery_link.dart';

void main() {
  final cases = <String, Type>{
    'https://app.test/?flow=recovery&code=example': RecoveryRequested,
    'https://app.test/#flow=recovery': RecoveryRequested,
    'https://app.test/?error_code=otp_expired': RecoveryExpired,
    'https://app.test/?error=access_denied': RecoveryExpired,
    'https://app.test/#error_code=otp_expired': RecoveryExpired,
    'https://app.test/#error=access_denied': RecoveryExpired,
    'https://app.test/?flow=recovery#error_code=otp_expired': RecoveryExpired,
    'https://app.test/?error_code=otp_expired#flow=recovery': RecoveryExpired,
    'https://app.test/': RecoveryNone,
    'https://app.test/#/sign-in': RecoveryNone,
    'https://app.test/?code=example': RecoveryNone,
    'https://app.test/?flow=other': RecoveryNone,
    'https://app.test/?error_code=other': RecoveryNone,
  };
  for (final entry in cases.entries) {
    test('AUTH-06: parses ${entry.key} as ${entry.value}', () {
      expect(RecoveryLink.parse(Uri.parse(entry.key)).runtimeType, entry.value);
    });
  }

  test('AUTH-06: link_expired is a client-only code', () {
    expect(ErrorCodes.linkExpired, 'link_expired');
    expect(ErrorCodes.isServerCode(ErrorCodes.linkExpired), isFalse);
  });
}
