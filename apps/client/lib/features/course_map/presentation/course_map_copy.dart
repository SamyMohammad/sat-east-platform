import 'package:sat_east_client/core/errors/error_codes.dart';

/// User-facing English copy for the course map (CLAUDE.md B.5: never show
/// raw exception text).
abstract final class CourseMapCopy {
  static const continueEyebrow = 'Continue where you left off';
  static const continueButton = 'Continue';
  static const freeChip = 'Free';
  static const statusCompleted = 'completed';
  static const statusOpen = 'open';
  static const statusLocked = 'locked';
  static const emptyTitle = 'No topics yet';
  static const emptyBody = 'This course has no topics yet.';
  static const notEnrolledTitle = 'No course yet';
  static const notEnrolledBody = "You're not enrolled in a course yet.";
  static const expiredTitle = 'Access ended';
  static const expiredBody = 'Your access has ended. Contact your teacher.';
  static const errorTitle = "Couldn't load your course";
  static const networkBody = 'Check your connection and try again.';
  static const genericBody = 'Something went wrong. Try again.';

  static String lockLine(String afterTitle) =>
      'Pass the $afterTitle quiz to unlock';

  static String errorBody(String code) =>
      code == ErrorCodes.network ? networkBody : genericBody;
}
