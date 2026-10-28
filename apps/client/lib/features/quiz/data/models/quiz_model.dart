import 'package:sat_east_client/core/attempts/attempt_json.dart';
import 'package:sat_east_client/core/attempts/attempt_model.dart';
import 'package:sat_east_client/features/quiz/domain/entities/quiz.dart';

export 'package:sat_east_client/core/attempts/attempt_model.dart'
    show saveOutcomeFromJson;

QuizSession quizSessionFromJson(Map<String, Object?> json) {
  final questions = attemptQuestionsFromJson(json);
  return QuizSession(
    attemptId: attemptJsonId(json, 'attempt_id'),
    title: attemptJsonString(json, 'title'),
    timeLimit: Duration(seconds: attemptJsonInt(json, 'time_limit_s', min: 1)),
    deadline: attemptJsonInstant(json, 'deadline'),
    serverNow: attemptJsonInstant(json, 'server_now'),
    warnAt: Duration(seconds: attemptJsonInt(json, 'warn_s')),
    questions: questions,
    answers: attemptAnswersFromJson(json, questions),
    clientSeq: attemptJsonInt(json, 'client_seq'),
  );
}

QuizReport quizReportFromJson(Map<String, Object?> json) {
  final raw = attemptJsonInt(json, 'score_raw');
  final total = attemptJsonInt(json, 'score_total', min: 1);
  if (raw > total) throw const FormatException('score_raw');
  final passMark = attemptJsonInt(json, 'pass_mark');
  if (passMark > 100) throw const FormatException('pass_mark');
  final next = attemptJsonRequired(json, 'next_topic');
  final nextTopic = next == null ? null : attemptJsonMap(next, 'next_topic');
  final retake = attemptJsonRequired(json, 'retake_at');
  return QuizReport(
    scoreRaw: raw,
    scoreTotal: total,
    scorePct: attemptJsonPercentage(json, 'score_pct'),
    passMark: passMark,
    passed: attemptJsonBool(json, 'passed'),
    nextTopic: nextTopic == null
        ? null
        : (
            id: attemptJsonId(nextTopic, 'id'),
            title: attemptJsonString(nextTopic, 'title'),
          ),
    retakeAt: retake == null ? null : attemptJsonInstant(json, 'retake_at'),
    skills: json.containsKey('skills')
        ? List.unmodifiable(
            attemptJsonList(json, 'skills').map(_quizSkillResultFromJson),
          )
        : const [],
  );
}

QuizSkillResult _quizSkillResultFromJson(Object? value) {
  final json = attemptJsonMap(value, 'skills');
  final correct = attemptJsonInt(json, 'correct');
  final total = attemptJsonInt(json, 'total', min: 1);
  if (correct > total) throw const FormatException('correct');
  return QuizSkillResult(
    code: attemptJsonId(json, 'code'),
    name: attemptJsonId(json, 'name'),
    correct: correct,
    total: total,
  );
}
