import 'package:sat_east_client/core/attempts/attempt_json.dart';
import 'package:sat_east_client/core/attempts/attempt_model.dart';
import 'package:sat_east_client/features/homework/domain/entities/homework.dart';

HomeworkSession homeworkSessionFromJson(Map<String, Object?> json) {
  final questions = attemptQuestionsFromJson(json);
  return HomeworkSession(
    attemptId: attemptJsonId(json, 'attempt_id'),
    title: attemptJsonString(json, 'title'),
    questions: questions,
    answers: attemptAnswersFromJson(json, questions),
    clientSeq: attemptJsonInt(json, 'client_seq'),
  );
}

HomeworkReport homeworkReportFromJson(Map<String, Object?> json) {
  if (attemptJsonString(json, 'kind') != 'homework') {
    throw const FormatException('kind');
  }
  final raw = attemptJsonInt(json, 'score_raw');
  final total = attemptJsonInt(json, 'score_total', min: 1);
  if (raw > total) throw const FormatException('score_raw');
  return HomeworkReport(
    attemptId: attemptJsonId(json, 'attempt_id'),
    scoreRaw: raw,
    scoreTotal: total,
    scorePct: attemptJsonPercentage(json, 'score_pct'),
  );
}
