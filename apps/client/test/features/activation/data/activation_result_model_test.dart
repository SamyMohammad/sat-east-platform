import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/features/activation/data/models/activation_result_model.dart';

import '../activation_fixtures.dart';

void main() {
  test('S-10: activation result maps all enrollment fields', () {
    final result = activationResultFromJson(activationPayload);

    expect(result.courseId, activationResult.courseId);
    expect(result.courseSlug, activationResult.courseSlug);
    expect(result.courseTitle, activationResult.courseTitle);
    expect(result.targetTestDate, activationResult.targetTestDate);
    expect(result.expiresAt, activationResult.expiresAt);
    expect(result.expiresAt.isUtc, isTrue);
  });
}
