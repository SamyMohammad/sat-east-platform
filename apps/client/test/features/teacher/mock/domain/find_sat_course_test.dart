import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/teacher/course_builder/domain/entities/teacher_course.dart';
import 'package:sat_east_client/features/teacher/mock/domain/usecases/find_sat_course.dart';

import '../../course_builder/builder_fixtures.dart';

void main() {
  test('MCK-03: picks the SAT course among EST and SAT', () async {
    final repo = FakeBuilderRepository()
      ..courses = Success(builderCourses.reversed.toList());
    final r = await FindSatCourse(repo)();
    expect((r as Success<TeacherCourse?>).value?.code, 'SAT');
  });

  test('MCK-03: no SAT course returns null, never the first course', () async {
    final repo = FakeBuilderRepository()
      ..courses = Success(
        builderCourses.where((c) => c.code != 'SAT').toList(),
      );
    final r = await FindSatCourse(repo)();
    expect((r as Success<TeacherCourse?>).value, isNull);
  });

  test('MCK-03: a list failure is passed through', () async {
    final repo = FakeBuilderRepository()
      ..courses = const Failure(AppError('forbidden'));
    final r = await FindSatCourse(repo)();
    expect((r as Failure).error.code, 'forbidden');
  });
}
