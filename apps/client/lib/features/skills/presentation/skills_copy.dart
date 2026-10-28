import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/presentation/learning_copy.dart';
import 'package:sat_east_client/features/skills/domain/entities/skills_overview.dart';

/// User-facing English copy for the Skills screen (CLAUDE.md B.5: never show
/// raw exception text).
abstract final class SkillsCopy {
  static const title = 'Skills';
  static const weakTitle = 'Weakest skills';
  static const weakThin = 'Not enough answers to name a weak skill yet.';
  static const practise = 'Practise this';
  static const trendTitle = 'Weekly trend';
  static const trendKeepPractising = 'Keep practising to see a trend.';
  static const skillsTitle = 'All skills';
  static const noSkills = 'Skills appear once questions are tagged.';
  static const topicsTitle = 'Topics';
  static const emptyTitle = 'No skills yet';
  static const emptyBody =
      'Answer a few practice questions and your skills show up here.';
  static const emptyAction = 'Go to your course';
  static const errorTitle = "Couldn't load your skills";
  static const String notEnrolledTitle = LearningCopy.notEnrolledTitle;
  static const String notEnrolledBody = LearningCopy.notEnrolledBody;
  static const String expiredTitle = LearningCopy.expiredTitle;
  static const String expiredBody = LearningCopy.expiredBody;
  static const activateAction = 'Enter activation code';
  static const browseAction = 'Browse courses';

  static String solved(int solved, int total) =>
      '$solved of $total questions solved';

  static String answers(int count) =>
      count == 1 ? '1 answer so far' : '$count answers so far';

  static String topicSolved(int solved, int total) =>
      '$solved of $total solved';

  static String trendNeedsAnswers(int missing) =>
      'Answer $missing more ${missing == 1 ? 'question' : 'questions'} '
      'to see a trend.';

  static String band(MasteryBand band) => switch (band) {
    MasteryBand.weak => 'Weak',
    MasteryBand.building => 'Building',
    MasteryBand.strong => 'Strong',
    MasteryBand.thin => 'Not enough answers yet',
  };

  static String mastery(double value) => '${value.round()}';

  static String trendSemantics(List<TrendPoint> points) =>
      'Weekly mastery, ${points.length} weeks, from '
      '${mastery(points.first.mastery)} to ${mastery(points.last.mastery)}';

  static String errorBody(String code) => code == ErrorCodes.network
      ? LearningCopy.networkBody
      : LearningCopy.genericBody;
}
