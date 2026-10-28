import 'package:equatable/equatable.dart';

import 'package:sat_east_client/core/attempts/attempt_json.dart';

class SkillResult extends Equatable {
  const SkillResult({
    required this.code,
    required this.name,
    required this.correct,
    required this.total,
  });

  final String code;
  final String name;
  final int correct;
  final int total;

  @override
  List<Object?> get props => [code, name, correct, total];
}

SkillResult skillResultFromJson(Object? value) {
  final json = attemptJsonMap(value, 'skills');
  final correct = attemptJsonInt(json, 'correct');
  final total = attemptJsonInt(json, 'total', min: 1);
  if (correct > total) throw const FormatException('correct');
  return SkillResult(
    code: attemptJsonId(json, 'code'),
    name: attemptJsonId(json, 'name'),
    correct: correct,
    total: total,
  );
}
