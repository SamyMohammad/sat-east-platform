import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/features/auth/data/models/my_enrollment_model.dart';

void main() {
  final now = DateTime.utc(2026, 10, 18, 12);
  const row = <String, Object?>{
    'target_test_date': '2027-03-15',
    'expires_at': '2027-03-30T00:00:00Z',
    'status': 'active',
    'courses': {'title': 'SAT Math'},
  };

  test('AUTH-02: enrollment mapper keeps the selected calendar date', () {
    final enrollment = myEnrollmentFromJson(row, now)!;

    expect(enrollment.courseTitle, 'SAT Math');
    expect(enrollment.targetTestDate, DateTime(2027, 3, 15));
    expect(enrollment.expiresAt, DateTime.utc(2027, 3, 30));
    expect(enrollment.isExpired, isFalse);
  });

  test('AUTH-02: enrollment mapper omits RLS-hidden courses', () {
    expect(myEnrollmentFromJson({...row, 'courses': null}, now), isNull);
  });

  test('AUTH-02: enrollment mapper retains a null test date', () {
    expect(
      myEnrollmentFromJson({
        ...row,
        'target_test_date': null,
      }, now)!.targetTestDate,
      isNull,
    );
  });

  for (final status in ['expired', 'refunded', 'suspended']) {
    test('AUTH-02: $status has ended despite a future access end', () {
      expect(
        myEnrollmentFromJson({...row, 'status': status}, now)!.isExpired,
        isTrue,
      );
    });
  }

  test('AUTH-02: access ends exactly at its expiry instant', () {
    expect(
      myEnrollmentFromJson(row, DateTime.utc(2027, 3, 30))!.isExpired,
      isTrue,
    );
    expect(
      myEnrollmentFromJson(
        row,
        DateTime.utc(2027, 3, 30).subtract(const Duration(microseconds: 1)),
      )!.isExpired,
      isFalse,
    );
  });

  for (final malformed in <Map<String, Object?>>[
    {
      ...row,
      'courses': {'title': 7},
    },
    {...row, 'status': 'unknown'},
    {...row, 'target_test_date': '2027-02-30'},
    {...row, 'expires_at': 'bad'},
  ]) {
    test('AUTH-02: mapper rejects malformed $malformed', () {
      expect(
        () => myEnrollmentFromJson(malformed, now),
        throwsFormatException,
      );
    });
  }
}
