import 'package:sat_east_client/features/activation/domain/entities/activation_result.dart';

ActivationResult activationResultFromJson(Map<String, Object?> json) =>
    ActivationResult(
      courseId: _string(json, 'course_id'),
      courseSlug: _string(json, 'course_slug'),
      courseTitle: _string(json, 'course_title'),
      targetTestDate: DateTime.parse(_string(json, 'target_test_date')),
      expiresAt: DateTime.parse(_string(json, 'expires_at')),
    );

String _string(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String || value.isEmpty) throw FormatException(key);
  return value;
}
