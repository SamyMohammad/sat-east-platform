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

  static const radarTitle = 'Domain mastery';
  static const notStarted = 'Not started';
  static const trendNoChange = 'No change';

  static String strongest(String domain) => 'Strongest: $domain';

  static String focusNext(String domain) => 'Focus next: $domain';

  /// "78 · Strong", or "Not started" while no skill is practised.
  static String domainValue(DomainMastery d) {
    final mean = d.mean;
    return mean == null ? notStarted : '${mastery(mean)} · ${band(d.band)}';
  }

  /// Axis label: "Algebra · 78 · Strong", or "Algebra · Not started".
  static String domainLabel(DomainMastery d) =>
      '${d.domain} · ${domainValue(d)}';

  static String startNext(String domain) => 'Start next: $domain';

  /// Size of a sparkline change; the arrow icon next to it shows direction.
  static String sparkDelta(int delta) => '${delta.abs()}';

  /// Spoken change of a sparkline, naming where it starts.
  static String sparkDeltaSpoken(int delta, {required DateTime since}) =>
      switch (delta) {
        0 => 'no change since ${shortDate(since)}',
        > 0 => 'up $delta points since ${shortDate(since)}',
        _ => 'down ${-delta} points since ${shortDate(since)}',
      };

  /// Spoken summary of the whole radar.
  static String radarSemantics(List<DomainMastery> domains) =>
      '$radarTitle: ${domains.map(_domainSpoken).join(', ')}';

  static String _domainSpoken(DomainMastery d) {
    final mean = d.mean;
    return mean == null
        ? '${d.domain} not started'
        : '${d.domain} ${mastery(mean)} ${band(d.band).toLowerCase()}';
  }

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  /// "Oct 12".
  static String shortDate(DateTime date) =>
      '${_months[date.month - 1]} ${date.day}';

  /// "+6 this week" when [since] and [until] are exactly a week apart,
  /// otherwise "+6 since Oct 5"; "−3 ..." uses a true minus sign; "No change"
  /// for zero.
  static String trendDelta(
    int delta, {
    required DateTime since,
    required DateTime until,
  }) {
    if (delta == 0) return trendNoChange;
    final span = until.difference(since).inDays == 7
        ? 'this week'
        : 'since ${shortDate(since)}';
    return delta > 0 ? '+$delta $span' : '−${-delta} $span';
  }

  /// "1m 12s", "45s" or "2m"; never shows less than one second.
  static String duration(Duration value) {
    final total = (value.inMilliseconds / 1000).round().clamp(1, 1 << 30);
    final minutes = total ~/ 60;
    final seconds = total % 60;
    if (minutes == 0) return '${seconds}s';
    return seconds == 0 ? '${minutes}m' : '${minutes}m ${seconds}s';
  }

  /// "82% correct · 1m 12s avg"; null when there are no attempts.
  static String? accuracyLine(SkillMastery skill) {
    final accuracy = skill.accuracy;
    if (skill.attempts == 0 || accuracy == null) return null;
    final avg = skill.avgTime;
    return avg == null
        ? '${accuracy.round()}% correct'
        : '${accuracy.round()}% correct · ${duration(avg)} avg';
  }

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
