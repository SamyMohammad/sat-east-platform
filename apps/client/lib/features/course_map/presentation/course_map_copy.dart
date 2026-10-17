import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/presentation/learning_copy.dart';

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
  static const String notEnrolledTitle = LearningCopy.notEnrolledTitle;
  static const String notEnrolledBody = LearningCopy.notEnrolledBody;
  static const String expiredTitle = LearningCopy.expiredTitle;
  static const String expiredBody = LearningCopy.expiredBody;
  static const errorTitle = "Couldn't load your course";
  static const String networkBody = LearningCopy.networkBody;
  static const String genericBody = LearningCopy.genericBody;

  static String lockLine(String afterTitle) =>
      'Pass the $afterTitle quiz to unlock';

  static String errorBody(String code) =>
      code == ErrorCodes.network ? networkBody : genericBody;
}
