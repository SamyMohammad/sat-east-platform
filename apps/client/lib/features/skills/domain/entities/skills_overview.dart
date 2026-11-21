import 'package:equatable/equatable.dart';

/// Mastery level of a skill or topic. [thin] means too few answers to rate.
enum MasteryBand { weak, building, strong, thin }

/// "X of Y questions solved" plus the number of graded answers behind it.
class SkillsSummary extends Equatable {
  const SkillsSummary({
    required this.solved,
    required this.total,
    required this.gradedAnswers,
    this.trendMinAnswers,
    this.strongAt,
  });

  final int solved;
  final int total;
  final int gradedAnswers;

  /// Graded answers needed before a trend is shown, when the server says so.
  final int? trendMinAnswers;

  /// Mastery (0-100) from which a skill counts as strong, when the server
  /// says so; the client draws its target line and radar ring from it.
  final int? strongAt;

  @override
  List<Object?> get props => [
    solved,
    total,
    gradedAnswers,
    trendMinAnswers,
    strongAt,
  ];
}

/// One skill with its mastery (0-100); [mastery] is null while [band] is thin.
class SkillMastery extends Equatable {
  const SkillMastery({
    required this.code,
    required this.name,
    required this.domain,
    required this.mastery,
    required this.attempts,
    required this.band,
    this.accuracy,
    this.avgTime,
    this.history = const [],
  });

  final String code;
  final String name;
  final String domain;
  final double? mastery;
  final int attempts;
  final MasteryBand band;

  /// Share of correct answers (0-100); null when there are no attempts.
  final double? accuracy;

  /// Average time per answer; null when unknown.
  final Duration? avgTime;

  /// Weekly mastery of this skill, oldest first; empty when under two weeks.
  final List<TrendPoint> history;

  @override
  List<Object?> get props => [
    code,
    name,
    domain,
    mastery,
    attempts,
    band,
    accuracy,
    avgTime,
    history,
  ];
}

/// Mean mastery of one domain; [mean] is null while no skill is practised.
class DomainMastery extends Equatable {
  const DomainMastery({
    required this.domain,
    required this.mean,
    required this.band,
    required this.practised,
    required this.total,
  });

  final String domain;
  final double? mean;
  final MasteryBand band;
  final int practised;
  final int total;

  @override
  List<Object?> get props => [domain, mean, band, practised, total];
}

/// Picks the strongest and the weakest domain for the radar chips.
extension DomainRanking on List<DomainMastery> {
  /// Highest mean among practised domains; null when none is practised.
  DomainMastery? get strongest => _pick(1);

  /// Lowest mean among practised domains; null unless two or more are
  /// practised and the lowest differs from the strongest.
  DomainMastery? get weakest {
    final high = strongest;
    final low = _pick(-1);
    return low == null || low == high ? null : low;
  }

  /// First domain with no practised skill, to nudge the student to start it.
  DomainMastery? get nextToStart {
    for (final d in this) {
      if (d.mean == null) return d;
    }
    return null;
  }

  DomainMastery? _pick(int direction) {
    DomainMastery? best;
    for (final d in this) {
      final mean = d.mean;
      if (mean == null) continue;
      if (best == null || (mean - best.mean!) * direction > 0) best = d;
    }
    return best;
  }
}

/// A weak skill and the topic where the student should practise it.
class WeakSkill extends Equatable {
  const WeakSkill({
    required this.code,
    required this.name,
    required this.mastery,
    required this.topicId,
    required this.topicTitle,
  });

  final String code;
  final String name;
  final double mastery;
  final String topicId;
  final String topicTitle;

  @override
  List<Object?> get props => [code, name, mastery, topicId, topicTitle];
}

/// Weekly mean mastery; [weekStart] is a calendar date (UTC midnight).
class TrendPoint extends Equatable {
  const TrendPoint({required this.weekStart, required this.mastery});

  final DateTime weekStart;
  final double mastery;

  @override
  List<Object?> get props => [weekStart, mastery];
}

/// Week-over-week change.
extension TrendDelta on List<TrendPoint> {
  /// Rounded change between the last two points; null with fewer than two.
  int? get weeklyDelta => length < 2
      ? null
      : (this[length - 1].mastery.round() - this[length - 2].mastery.round());

  /// Rounded change from the first to the last point (the span a sparkline
  /// shows); null with fewer than two points.
  int? get spanDelta =>
      length < 2 ? null : (last.mastery.round() - first.mastery.round());
}

/// Per-topic progress and level.
class TopicLevel extends Equatable {
  const TopicLevel({
    required this.topicId,
    required this.title,
    required this.unitTitle,
    required this.solved,
    required this.total,
    required this.level,
  });

  final String topicId;
  final String title;
  final String? unitTitle;
  final int solved;
  final int total;
  final MasteryBand level;

  @override
  List<Object?> get props => [topicId, title, unitTitle, solved, total, level];
}

/// The student's skills picture for one course (aggregates only).
class SkillsOverview extends Equatable {
  const SkillsOverview({
    required this.summary,
    required this.skills,
    required this.weak,
    required this.trend,
    required this.topics,
    this.domains = const [],
  });

  final SkillsSummary summary;
  final List<SkillMastery> skills;
  final List<WeakSkill> weak;
  final List<TrendPoint> trend;
  final List<TopicLevel> topics;

  /// Mean mastery per domain, for the radar; empty when nothing is tagged.
  final List<DomainMastery> domains;

  @override
  List<Object?> get props => [summary, skills, weak, trend, topics, domains];
}
