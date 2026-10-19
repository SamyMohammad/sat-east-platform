import 'package:sat_east_client/features/auth/domain/entities/my_enrollment.dart';

MyEnrollment? myEnrollmentFromJson(Map<String, Object?> json, DateTime now) {
  final course = json['courses'];
  // Course RLS hides an enrolled course once it is unpublished.
  if (json.containsKey('courses') && course == null) return null;
  if (course is! Map<String, Object?>) {
    throw const FormatException('courses');
  }
  final title = course['title'];
  if (title is! String || title.isEmpty) {
    throw const FormatException('courses.title');
  }
  final status = json['status'];
  if (!const {'active', 'expired', 'refunded', 'suspended'}.contains(status)) {
    throw const FormatException('status');
  }
  final expiresAt = _date(json['expires_at'], 'expires_at');
  final targetTestDate = json['target_test_date'];
  return MyEnrollment(
    courseTitle: title,
    targetTestDate: targetTestDate == null
        ? null
        : _calendarDate(targetTestDate),
    expiresAt: expiresAt,
    isExpired: status != 'active' || !expiresAt.isAfter(now),
  );
}

DateTime _date(Object? value, String field) {
  if (value is! String) throw FormatException(field);
  return DateTime.parse(value);
}

DateTime _calendarDate(Object value) {
  if (value is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
    throw const FormatException('target_test_date');
  }
  final date = DateTime.parse(value);
  // DateTime.parse normalizes impossible days instead of rejecting them.
  if (date.toIso8601String().split('T').first != value) {
    throw const FormatException('target_test_date');
  }
  return date;
}
