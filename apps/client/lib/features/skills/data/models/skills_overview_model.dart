import 'package:sat_east_client/core/attempts/attempt_json.dart';
import 'package:sat_east_client/features/skills/domain/entities/skills_overview.dart';

/// Parses the `get_my_skills` payload; throws [FormatException] when a field
/// is missing or mistyped. An unknown band falls back to thin.
SkillsOverview skillsOverviewFromJson(
  Map<String, Object?> json,
) {
  final summary = attemptJsonMap(json['summary'], 'summary');
  return SkillsOverview(
    summary: SkillsSummary(
      solved: attemptJsonInt(summary, 'solved'),
      total: attemptJsonInt(summary, 'total'),
      gradedAnswers: attemptJsonInt(summary, 'graded_answers'),
      trendMinAnswers: attemptJsonInt(summary, 'trend_min_answers', min: 1),
    ),
    skills: [
      for (final s in attemptJsonList(json, 'skills'))
        _skill(attemptJsonMap(s, 'skills[]')),
    ],
    weak: [
      for (final w in attemptJsonList(json, 'weak'))
        _weak(attemptJsonMap(w, 'weak[]')),
    ],
    trend: [
      for (final t in attemptJsonList(json, 'trend'))
        _trend(attemptJsonMap(t, 'trend[]')),
    ],
    topics: [
      for (final t in attemptJsonList(json, 'topics'))
        _topic(attemptJsonMap(t, 'topics[]')),
    ],
  );
}

SkillMastery _skill(Map<String, Object?> json) => SkillMastery(
  code: attemptJsonString(json, 'code'),
  name: attemptJsonString(json, 'name'),
  domain: attemptJsonString(json, 'domain'),
  mastery: _optNum(json, 'mastery'),
  attempts: attemptJsonInt(json, 'attempts'),
  band: _band(json['band']),
);

WeakSkill _weak(Map<String, Object?> json) => WeakSkill(
  code: attemptJsonString(json, 'code'),
  name: attemptJsonString(json, 'name'),
  mastery: _num(json, 'mastery'),
  topicId: attemptJsonId(json, 'topic_id'),
  topicTitle: attemptJsonString(json, 'topic_title'),
);

TrendPoint _trend(Map<String, Object?> json) => TrendPoint(
  weekStart: _date(attemptJsonString(json, 'week_start')),
  mastery: _num(json, 'mastery'),
);

TopicLevel _topic(Map<String, Object?> json) {
  final unit = json['unit_title'];
  if (unit != null && unit is! String) throw const FormatException('unit');
  return TopicLevel(
    topicId: attemptJsonId(json, 'topic_id'),
    title: attemptJsonString(json, 'title'),
    unitTitle: unit as String?,
    solved: attemptJsonInt(json, 'solved'),
    total: attemptJsonInt(json, 'total'),
    level: _band(json['level']),
  );
}

MasteryBand _band(Object? value) => switch (value) {
  'weak' => MasteryBand.weak,
  'building' => MasteryBand.building,
  'strong' => MasteryBand.strong,
  _ => MasteryBand.thin,
};

double _num(Map<String, Object?> json, String field) {
  final value = json[field];
  return value is num && value.isFinite
      ? value.toDouble()
      : throw FormatException(field);
}

double? _optNum(Map<String, Object?> json, String field) =>
    json[field] == null ? null : _num(json, field);

DateTime _date(String value) {
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
    throw const FormatException('week_start');
  }
  final parsed = DateTime.parse(value);
  return DateTime.utc(parsed.year, parsed.month, parsed.day);
}
