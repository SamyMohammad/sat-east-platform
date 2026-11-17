import 'package:sat_east_client/core/attempts/attempt_json.dart';
import 'package:sat_east_client/core/attempts/attempt_question.dart';
import 'package:sat_east_client/core/attempts/save_outcome.dart';

List<AttemptQuestion> attemptQuestionsFromJson(
  Map<String, Object?> json, {
  bool difficultyHidden = false,
}) {
  final questions = [
    for (final value in attemptJsonList(json, 'questions'))
      attemptQuestionFromJson(
        attemptJsonMap(value, 'questions[]'),
        difficultyHidden: difficultyHidden,
      ),
  ];
  if (questions.isEmpty ||
      questions.map((q) => q.id).toSet().length != questions.length) {
    throw const FormatException('questions');
  }
  return List.unmodifiable(questions);
}

Map<String, SavedAnswer> attemptAnswersFromJson(
  Map<String, Object?> json,
  List<AttemptQuestion> questions, {
  bool withEliminated = false,
}) {
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
      eliminated: withEliminated ? _eliminated(saved) : const {},
    );
  }
  return Map.unmodifiable(answers);
}

Set<String> _eliminated(Map<String, Object?> saved) {
  final value = saved['eliminated'];
  if (value == null) return const {};
  if (value is! List || value.any((label) => label is! String)) {
    throw const FormatException('eliminated');
  }
  return Set.unmodifiable(value.cast<String>());
}

/// [difficultyHidden] for mock payloads, which omit it (it would reveal the
/// route); the default keeps the strict quiz behaviour.
AttemptQuestion attemptQuestionFromJson(
  Map<String, Object?> json, {
  bool difficultyHidden = false,
}) {
  final kind = switch (attemptJsonString(json, 'type')) {
    'mcq' => AttemptKind.mcq,
    'spr' => AttemptKind.spr,
    _ => throw const FormatException('type'),
  };
  final difficulty = difficultyHidden
      ? null
      : attemptJsonString(json, 'difficulty');
  if (!difficultyHidden &&
      difficulty != 'E' &&
      difficulty != 'M' &&
      difficulty != 'H') {
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
