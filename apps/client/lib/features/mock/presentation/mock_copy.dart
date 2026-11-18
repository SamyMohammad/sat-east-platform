import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/presentation/learning_copy.dart';

/// English copy for the student mock exam screens.
abstract final class MockCopy {
  static const hubTitle = 'Mock exams';
  static const hubIntro =
      'Full-length SAT Math practice exams, timed in two modules.';
  static const noCourseTitle = 'Mock exams are available with a SAT enrolment';
  static const noCourseMessage =
      'Enrol in the SAT course to unlock your mock exams.';
  static const noFormsTitle = 'No mock exams yet';
  static const noFormsMessage = 'Your teacher has not published one yet.';

  static const start = 'Start';
  static const resume = 'Resume';
  static const finished = 'Finished';
  static const available = 'Available';
  static const inProgress = 'In progress';
  static const locked = 'Locked';
  static const retry = 'Retry';

  static String formTitle(int k) => 'Mock exam $k';

  static String unlockHint(int need, int passed) => need == 1
      ? 'Pass 1 topic to unlock. You have passed $passed.'
      : 'Pass $need topics to unlock. You have passed $passed.';

  static const preExamTitle = 'Before you start';
  static const preExamIntro = 'This mock follows the real test format.';
  static const preExamRules = [
    'Two modules, 22 questions and 35 minutes each.',
    'The timer does not pause, even if you leave the page.',
    'Once you submit a module you cannot go back to it.',
    'There is a short break between the modules.',
    'Your second module depends on how you do in the first.',
    'You will see an estimated score range at the end.',
  ];
  static const phoneBanner =
      'A laptop or tablet works best for a full-length mock exam.';
  static const startModule1 = 'Start module 1';

  static String errorTitle(String code) => switch (code) {
    ErrorCodes.mockLocked => 'Mock exam locked',
    ErrorCodes.mockNoneAvailable => 'No mock exam available',
    ErrorCodes.notEnrolled => LearningCopy.notEnrolledTitle,
    ErrorCodes.accessExpired => LearningCopy.expiredTitle,
    ErrorCodes.rateLimited => 'Too many tries',
    _ => 'Something went wrong',
  };

  static String errorBody(String code) => switch (code) {
    ErrorCodes.mockLocked =>
      'Pass more topic quizzes to unlock the next mock exam.',
    ErrorCodes.mockNoneAvailable =>
      "You've taken every mock exam that is available right now.",
    ErrorCodes.notEnrolled => LearningCopy.notEnrolledBody,
    ErrorCodes.accessExpired => LearningCopy.expiredBody,
    ErrorCodes.rateLimited => 'Wait a moment, then try again.',
    ErrorCodes.network => LearningCopy.networkBody,
    _ => LearningCopy.genericBody,
  };
}
