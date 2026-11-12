import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/teacher/course_builder/domain/entities/teacher_course.dart';
import 'package:sat_east_client/features/teacher/course_builder/domain/repositories/course_builder_repository.dart';

/// Finds the SAT course the mock exam pages work on. Mock exams exist for SAT
/// only, so this never falls back to another course: no SAT course gives
/// `Success(null)`.
class FindSatCourse {
  const FindSatCourse(this._courses);
  final CourseBuilderRepository _courses;

  static const code = 'SAT';

  Future<Result<TeacherCourse?>> call() async =>
      switch (await _courses.listCourses()) {
        Success(:final value) => Success(
          value.where((c) => c.code == code).firstOrNull,
        ),
        Failure(:final error) => Failure(error),
      };
}
