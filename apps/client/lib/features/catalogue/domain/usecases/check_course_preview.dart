import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/catalogue/domain/entities/course_page.dart';
import 'package:sat_east_client/features/course_map/domain/entities/course_map.dart';
import 'package:sat_east_client/features/course_map/domain/repositories/course_map_repository.dart';

class CheckCoursePreview {
  const CheckCoursePreview(this._maps);

  final CourseMapRepository _maps;

  Future<Result<bool>> call(CoursePage page, {required bool signedIn}) async {
    if (!signedIn || !page.hasFreeTopic) return const Success(false);
    return switch (await _maps.getCourseMap(slug: page.slug)) {
      Success(:final value) => Success(value.access == CourseAccess.preview),
      Failure(:final error) when error.code == ErrorCodes.accessExpired =>
        const Success(false),
      Failure(:final error) => Failure(error),
    };
  }
}
