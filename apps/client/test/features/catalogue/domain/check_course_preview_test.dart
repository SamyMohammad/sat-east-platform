import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/catalogue/data/models/course_page_model.dart';
import 'package:sat_east_client/features/catalogue/domain/usecases/check_course_preview.dart';
import 'package:sat_east_client/features/course_map/domain/entities/course_map.dart';

import '../catalogue_fixtures.dart';

void main() {
  for (final access in CourseAccess.values) {
    test(
      'CRS-06: preview eligibility uses per-course $access access',
      () async {
        final maps = FakePreviewMapRepository()
          ..result = Success(
            CourseMap(
              courseId: 'c1',
              slug: 'sat-math',
              title: 'SAT Math',
              continueTopic: null,
              units: const [],
              access: access,
            ),
          );
        final result = await CheckCoursePreview(maps)(
          coursePageFromJson(pagePayload),
          signedIn: true,
        );
        expect((result as Success<bool>).value, access == CourseAccess.preview);
        expect(maps.slugs, ['sat-math']);
      },
    );
  }
  for (final code in ['access_expired', 'network']) {
    test('CRS-06: preview eligibility handles $code', () async {
      final maps = FakePreviewMapRepository()..result = Failure(AppError(code));
      final result = await CheckCoursePreview(maps)(
        coursePageFromJson(pagePayload),
        signedIn: true,
      );
      if (code == 'access_expired') {
        expect((result as Success<bool>).value, isFalse);
      } else {
        expect((result as Failure<bool>).error.code, code);
      }
    });
  }
}
