import 'package:sat_east_client/core/attempts/attempt_json.dart';
import 'package:sat_east_client/core/attempts/attempt_question.dart';
import 'package:sat_east_client/core/attempts/skill_result.dart';
import 'package:sat_east_client/features/attempt_review/domain/entities/attempt_review.dart';

AttemptReview attemptReviewFromJson(Map<String, Object?> json) {
  final summary = attemptJsonMap(json['summary'], 'summary');
  final visible = attemptJsonBool(summary, 'keys_visible');
  final raw = attemptJsonInt(summary, 'score_raw');
  final total = attemptJsonInt(summary, 'score_total', min: 1);
  if (raw > total) throw const FormatException('score_raw');
  final mark = summary['pass_mark'] == null
      ? null
      : attemptJsonInt(summary, 'pass_mark');
  if (mark != null && mark > 100) throw const FormatException('pass_mark');
  final questions = [
    for (final item in attemptJsonList(json, 'questions'))
      _question(attemptJsonMap(item, 'question'), visible: visible),
  ];
  if (questions.map((q) => q.id).toSet().length != questions.length) {
    throw const FormatException('questions');
  }
  return AttemptReview(
    scoreRaw: raw,
    scoreTotal: total,
    scorePct: attemptJsonPercentage(summary, 'score_pct'),
    keysVisible: visible,
    passMark: mark,
    passed: summary['passed'] == null
        ? null
        : attemptJsonBool(summary, 'passed'),
    questions: List.unmodifiable(questions),
    skills: summary.containsKey('skills')
        ? List.unmodifiable(
            attemptJsonList(summary, 'skills').map(skillResultFromJson),
          )
        : const [],
  );
}

ReviewQuestion _question(Map<String, Object?> json, {required bool visible}) {
  final type = attemptJsonString(json, 'type');
  if (type != 'mcq' && type != 'spr') throw const FormatException('type');
  final key = visible && json['key'] != null
      ? attemptJsonMap(json['key'], 'key')
      : null;
  return ReviewQuestion(
    id: attemptJsonId(json, 'id'),
    stemMd: attemptJsonString(json, 'stem_md'),
    choices: List.unmodifiable([
      for (final item in attemptJsonList(json, 'choices'))
        _choice(attemptJsonMap(item, 'choice')),
    ]),
    myAnswer: _optionalString(json, 'my_answer'),
    isCorrect: attemptJsonBool(json, 'is_correct'),
    timeMs: attemptJsonInt(json, 'time_ms'),
    key: key == null
        ? null
        : _optionalString(key, type == 'mcq' ? 'choice' : 'text'),
    explanationMd: visible ? _optionalString(json, 'explanation_md') : null,
  );
}

AttemptChoice _choice(Map<String, Object?> json) => AttemptChoice(
  attemptJsonString(json, 'label'),
  attemptJsonString(json, 'body_md'),
);
String? _optionalString(Map<String, Object?> json, String field) {
  final value = json[field];
  if (value != null && value is! String) throw FormatException(field);
  return value as String?;
}
