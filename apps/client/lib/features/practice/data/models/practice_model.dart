import 'package:sat_east_client/features/practice/domain/entities/practice.dart';

/// Parses the keyless question set returned by `get_practice_questions`.
PracticeSet practiceSetFromJson(Map<String, Object?> json) => PracticeSet(
  attemptId: _str(json, 'attempt_id'),
  repTarget: _int(json, 'rep_target'),
  questions: [
    for (final question in _list(json, 'questions'))
      _question(_asMap(question, 'questions[]')),
  ],
);

/// Parses server feedback; malformed responses throw [FormatException].
CheckResult checkResultFromJson(Map<String, Object?> json) {
  final correct = json['is_correct'];
  if (correct is! bool) throw const FormatException('is_correct');
  final tryNo = _int(json, 'try');
  if (tryNo != 1 && tryNo != 2) throw const FormatException('try');
  if (!correct && tryNo == 1) {
    return CheckMiss(
      hintMd: _optStr(json, 'hint_md'),
      misconceptionMd: _optStr(json, 'misconception_md'),
    );
  }
  final key = _reveal(_asMap(json['key'], 'key'));
  final explanation = _optStr(json, 'explanation_md');
  return correct
      ? CheckCorrect(tryNo: tryNo, key: key, explanationMd: explanation)
      : CheckRevealed(key: key, explanationMd: explanation);
}

PracticeQuestion _question(Map<String, Object?> json) {
  final kind = switch (_str(json, 'type')) {
    'mcq' => PracticeKind.mcq,
    'spr' => PracticeKind.spr,
    final other => throw FormatException('unknown type: $other'),
  };
  final difficulty = _str(json, 'difficulty');
  if (difficulty != 'E' && difficulty != 'M' && difficulty != 'H') {
    throw const FormatException('difficulty');
  }
  return PracticeQuestion(
    id: _str(json, 'id'),
    kind: kind,
    difficulty: difficulty,
    stemMd: _str(json, 'stem_md'),
    choices: [
      for (final choice in _list(json, 'choices'))
        _choice(_asMap(choice, 'choices[]')),
    ],
  );
}

PracticeChoice _choice(Map<String, Object?> json) =>
    PracticeChoice(_str(json, 'label'), _str(json, 'body_md'));

AnswerReveal _reveal(Map<String, Object?> json) {
  if (json.length == 1) {
    if (json.containsKey('choice')) return ChoiceReveal(_str(json, 'choice'));
    if (json.containsKey('text')) return TextReveal(_str(json, 'text'));
  }
  throw const FormatException('key');
}

Map<String, Object?> _asMap(Object? value, String field) =>
    value is Map<String, Object?> ? value : throw FormatException(field);

List<Object?> _list(Map<String, Object?> json, String field) {
  final value = json[field];
  return value is List ? value.cast<Object?>() : throw FormatException(field);
}

String _str(Map<String, Object?> json, String field) {
  final value = json[field];
  return value is String ? value : throw FormatException(field);
}

String? _optStr(Map<String, Object?> json, String field) {
  final value = json[field];
  if (value == null) return null;
  return value is String ? value : throw FormatException(field);
}

int _int(Map<String, Object?> json, String field) {
  final value = json[field];
  return value is int ? value : throw FormatException(field);
}
