import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/course_map/domain/entities/course_map.dart';

// A domain port; more course-map reads will join it.
// ignore: one_member_abstracts
abstract interface class CourseMapRepository {
  /// Loads the map for [slug], or the student's current course when null.
  Future<Result<CourseMap>> getCourseMap({String? slug});
}
