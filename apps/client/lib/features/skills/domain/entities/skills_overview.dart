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
  });

  final int solved;
  final int total;
  final int gradedAnswers;

  /// Graded answers needed before a trend is shown, when the server says so.
  final int? trendMinAnswers;

  @override
  List<Object?> get props => [solved, total, gradedAnswers, trendMinAnswers];
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
  });

  final String code;
  final String name;
  final String domain;
  final double? mastery;
  final int attempts;
  final MasteryBand band;

  @override
  List<Object?> get props => [code, name, domain, mastery, attempts, band];
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
  });

  final SkillsSummary summary;
  final List<SkillMastery> skills;
  final List<WeakSkill> weak;
  final List<TrendPoint> trend;
  final List<TopicLevel> topics;

  @override
  List<Object?> get props => [summary, skills, weak, trend, topics];
}
