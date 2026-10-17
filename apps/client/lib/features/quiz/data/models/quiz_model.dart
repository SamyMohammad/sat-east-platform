import 'package:sat_east_client/features/quiz/data/models/quiz_json.dart';
import 'package:sat_east_client/features/quiz/domain/entities/quiz.dart';

QuizSession quizSessionFromJson(Map<String, Object?> json) {
  final questions = [
    for (final value in quizJsonList(json, 'questions'))
      _question(quizJsonMap(value, 'questions[]')),
  ];
  final questionIds = questions.map((q) => q.id).toSet();
  if (questions.isEmpty || questionIds.length != questions.length) {
    throw const FormatException('questions');
  }
  final answers = <String, SavedAnswer>{};
  for (final value in quizJsonList(json, 'answers')) {
    final saved = quizJsonMap(value, 'answers[]');
    final id = quizJsonId(saved, 'question_id');
    if (!questionIds.contains(id) || answers.containsKey(id)) {
      throw const FormatException('question_id');
    }
    final answer = quizJsonRequired(saved, 'answer');
    if (answer != null && answer is! String) {
      throw const FormatException('answer');
    }
    answers[id] = SavedAnswer(
      answer: answer as String?,
      marked: quizJsonBool(saved, 'marked'),
    );
  }
  return QuizSession(
    attemptId: quizJsonId(json, 'attempt_id'),
    title: quizJsonString(json, 'title'),
    timeLimit: Duration(seconds: quizJsonInt(json, 'time_limit_s', min: 1)),
    deadline: quizJsonInstant(json, 'deadline'),
    serverNow: quizJsonInstant(json, 'server_now'),
    warnAt: Duration(seconds: quizJsonInt(json, 'warn_s')),
    questions: List.unmodifiable(questions),
    answers: Map.unmodifiable(answers),
    clientSeq: quizJsonInt(json, 'client_seq'),
  );
}

QuizQuestion _question(Map<String, Object?> json) {
  final kind = switch (quizJsonString(json, 'type')) {
    'mcq' => QuizKind.mcq,
    'spr' => QuizKind.spr,
    _ => throw const FormatException('type'),
  };
  final difficulty = quizJsonString(json, 'difficulty');
  if (difficulty != 'E' && difficulty != 'M' && difficulty != 'H') {
    throw const FormatException('difficulty');
  }
  return QuizQuestion(
    id: quizJsonId(json, 'id'),
    kind: kind,
    difficulty: difficulty,
    stemMd: quizJsonString(json, 'stem_md'),
    choices: List.unmodifiable([
      for (final value in quizJsonList(json, 'choices'))
        _choice(quizJsonMap(value, 'choices[]')),
    ]),
  );
}

QuizChoice _choice(Map<String, Object?> json) => QuizChoice(
  quizJsonString(json, 'label'),
  quizJsonString(json, 'body_md'),
);

QuizReport quizReportFromJson(Map<String, Object?> json) {
  final raw = quizJsonInt(json, 'score_raw');
  final total = quizJsonInt(json, 'score_total', min: 1);
  if (raw > total) throw const FormatException('score_raw');
  final passMark = quizJsonInt(json, 'pass_mark');
  if (passMark > 100) throw const FormatException('pass_mark');
  final next = quizJsonRequired(json, 'next_topic');
  final nextTopic = next == null ? null : quizJsonMap(next, 'next_topic');
  final retake = quizJsonRequired(json, 'retake_at');
  return QuizReport(
    scoreRaw: raw,
    scoreTotal: total,
    scorePct: quizJsonPercentage(json, 'score_pct'),
    passMark: passMark,
    passed: quizJsonBool(json, 'passed'),
    nextTopic: nextTopic == null
        ? null
        : (
            id: quizJsonId(nextTopic, 'id'),
            title: quizJsonString(nextTopic, 'title'),
          ),
    retakeAt: retake == null ? null : quizJsonInstant(json, 'retake_at'),
  );
}

SaveOutcome saveOutcomeFromJson(Map<String, Object?> json) {
  if (!quizJsonBool(json, 'ok')) throw const FormatException('ok');
  final stale = json.containsKey('stale') && quizJsonBool(json, 'stale');
  return stale ? SaveOutcome.stale : SaveOutcome.saved;
}
