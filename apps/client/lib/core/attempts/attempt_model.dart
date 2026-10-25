import 'package:sat_east_client/core/attempts/attempt_json.dart';
import 'package:sat_east_client/core/attempts/attempt_question.dart';
import 'package:sat_east_client/core/attempts/save_outcome.dart';

List<AttemptQuestion> attemptQuestionsFromJson(Map<String, Object?> json) {
  final questions = [
    for (final value in attemptJsonList(json, 'questions'))
      attemptQuestionFromJson(attemptJsonMap(value, 'questions[]')),
  ];
  if (questions.isEmpty ||
      questions.map((q) => q.id).toSet().length != questions.length) {
    throw const FormatException('questions');
  }
  return List.unmodifiable(questions);
}

Map<String, SavedAnswer> attemptAnswersFromJson(
  Map<String, Object?> json,
  List<AttemptQuestion> questions,
) {
  final questionIds = questions.map((q) => q.id).toSet();
  if (questions.isEmpty || questionIds.length != questions.length) {
    throw const FormatException('questions');
  }
  final answers = <String, SavedAnswer>{};
  for (final value in attemptJsonList(json, 'answers')) {
    final saved = attemptJsonMap(value, 'answers[]');
    final id = attemptJsonId(saved, 'question_id');
    if (!questionIds.contains(id) || answers.containsKey(id)) {
      throw const FormatException('question_id');
    }
    final answer = attemptJsonRequired(saved, 'answer');
    if (answer != null && answer is! String) {
      throw const FormatException('answer');
    }
    answers[id] = SavedAnswer(
      answer: answer as String?,
      marked: attemptJsonBool(saved, 'marked'),
    );
  }
  return Map.unmodifiable(answers);
}

AttemptQuestion attemptQuestionFromJson(Map<String, Object?> json) {
  final kind = switch (attemptJsonString(json, 'type')) {
    'mcq' => AttemptKind.mcq,
    'spr' => AttemptKind.spr,
    _ => throw const FormatException('type'),
  };
  final difficulty = attemptJsonString(json, 'difficulty');
  if (difficulty != 'E' && difficulty != 'M' && difficulty != 'H') {
    throw const FormatException('difficulty');
  }
  return AttemptQuestion(
    id: attemptJsonId(json, 'id'),
    kind: kind,
    difficulty: difficulty,
    stemMd: attemptJsonString(json, 'stem_md'),
    choices: List.unmodifiable([
      for (final value in attemptJsonList(json, 'choices'))
        _choice(attemptJsonMap(value, 'choices[]')),
    ]),
  );
}

AttemptChoice _choice(Map<String, Object?> json) => AttemptChoice(
  attemptJsonString(json, 'label'),
  attemptJsonString(json, 'body_md'),
);

SaveOutcome saveOutcomeFromJson(Map<String, Object?> json) {
  if (!attemptJsonBool(json, 'ok')) throw const FormatException('ok');
  final stale = json.containsKey('stale') && attemptJsonBool(json, 'stale');
  return stale ? SaveOutcome.stale : SaveOutcome.saved;
}
