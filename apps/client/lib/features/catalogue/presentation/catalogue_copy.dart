import 'package:sat_east_client/core/errors/error_codes.dart';

abstract final class CatalogueCopy {
  static const title = 'Courses';
  static const syllabus = 'See the syllabus';
  static const contents = 'Contents';
  static const free = 'Free';
  static const activation = 'Have an activation code?';
  static const appNote = 'Sign in or enter an activation code.';
  static const emptyTitle = 'No courses yet';
  static const emptyBody = "Courses will appear here once they're published.";
  static const notFoundTitle = 'Course not found';
  static const notFoundBody = "This course isn't available.";
  static const browse = 'Browse courses';
  static const errorTitle = "Couldn't load courses";

  static String topics(int count) => '$count topics';
  static String subtopics(int count) => '$count subtopics';
  static String errorBody(String code) => code == ErrorCodes.network
      ? 'Check your connection and try again.'
      : 'Something went wrong. Try again.';
}
