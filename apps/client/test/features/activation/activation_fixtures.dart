import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/activation/domain/entities/activation_result.dart';
import 'package:sat_east_client/features/activation/domain/repositories/activation_repository.dart';

const activationPayload = <String, Object?>{
  'ok': true,
  'course_id': 'course-1',
  'course_slug': 'sat-math',
  'course_title': 'SAT Math',
  'target_test_date': '2027-03-15',
  'expires_at': '2027-03-30T00:00:00Z',
};

final activationResult = ActivationResult(
  courseId: 'course-1',
  courseSlug: 'sat-math',
  courseTitle: 'SAT Math',
  targetTestDate: DateTime(2027, 3, 15),
  expiresAt: DateTime.utc(2027, 3, 30),
);

class FakeActivationRepository implements ActivationRepository {
  Result<ActivationResult> result = Success(activationResult);
  Future<Result<ActivationResult>>? pending;
  final calls = <(String, DateTime)>[];

  @override
  Future<Result<ActivationResult>> redeem(String code, DateTime testDate) {
    calls.add((code, testDate));
    return pending ?? Future.value(result);
  }
}
