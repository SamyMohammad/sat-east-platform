import 'package:sat_east_client/core/attempts/attempt_json.dart';
import 'package:sat_east_client/core/attempts/attempt_model.dart';
import 'package:sat_east_client/features/mock/domain/entities/mock_entities.dart';

export 'package:sat_east_client/core/attempts/attempt_model.dart'
    show saveOutcomeFromJson;

MockHub mockHubFromJson(Map<String, Object?> json) {
  final active = attemptJsonRequired(json, 'active_group');
  if (active != null && (active is! String || active.trim().isEmpty)) {
    throw const FormatException('active_group');
  }
  return MockHub(
    passedTopics: attemptJsonInt(json, 'passed_topics'),
    forms: List.unmodifiable([
      for (final value in attemptJsonList(json, 'forms'))
        _hubForm(attemptJsonMap(value, 'forms[]')),
    ]),
    activeGroup: active as String?,
  );
}

MockHubForm _hubForm(Map<String, Object?> json) => MockHubForm(
  formNo: attemptJsonInt(json, 'form_no', min: 1),
  k: attemptJsonInt(json, 'k', min: 1),
  need: attemptJsonInt(json, 'need'),
  state: switch (attemptJsonString(json, 'state')) {
    'locked' => MockFormState.locked,
    'available' => MockFormState.available,
    'in_progress' => MockFormState.inProgress,
    'finished' => MockFormState.finished,
    _ => throw const FormatException('state'),
  },
);

MockStage mockStageFromJson(Map<String, Object?> json) {
  final groupId = attemptJsonId(json, 'group_id');
  return switch (attemptJsonString(json, 'stage')) {
    'module' =>
      json.containsKey('questions')
          ? MockModuleStage(_module(json, groupId))
          : MockModuleStartedStage(groupId: groupId, moduleNo: _moduleNo(json)),
    'gap' => MockGapStage(
      groupId: groupId,
      gapUntil: attemptJsonInstant(json, 'gap_until'),
      serverNow: attemptJsonInstant(json, 'server_now'),
    ),
    'finished' => MockFinishedStage(
      groupId: groupId,
      resultId: attemptJsonId(json, 'result_id'),
    ),
    _ => throw const FormatException('stage'),
  };
}

int _moduleNo(Map<String, Object?> json) {
  final value = attemptJsonInt(json, 'module_no', min: 1);
  if (value > 2) throw const FormatException('module_no');
  return value;
}

MockModule _module(Map<String, Object?> json, String groupId) {
  final questions = attemptQuestionsFromJson(json, difficultyHidden: true);
  return MockModule(
    groupId: groupId,
    moduleNo: _moduleNo(json),
    attemptId: attemptJsonId(json, 'attempt_id'),
    title: attemptJsonString(json, 'title'),
    timeLimitS: attemptJsonInt(json, 'time_limit_s', min: 1),
    deadline: attemptJsonInstant(json, 'deadline'),
    serverNow: attemptJsonInstant(json, 'server_now'),
    warnS: attemptJsonInt(json, 'warn_s'),
    questions: questions,
    answers: attemptAnswersFromJson(json, questions, withEliminated: true),
    clientSeq: attemptJsonInt(json, 'client_seq'),
  );
}

/// Parses one `mock_results` row.
MockResult mockResultFromJson(Map<String, Object?> json) {
  final low = json['est_low'];
  final high = json['est_high'];
  if ((low != null && low is! int) || (high != null && high is! int)) {
    throw const FormatException('est');
  }
  final breakdown = json['domain_breakdown'];
  if (breakdown != null && breakdown is! List) {
    throw const FormatException('domain_breakdown');
  }
  return MockResult(
    id: attemptJsonId(json, 'id'),
    route: attemptJsonString(json, 'route'),
    rawM1: attemptJsonInt(json, 'raw_m1'),
    rawM2: attemptJsonInt(json, 'raw_m2'),
    estLow: low as int?,
    estHigh: high as int?,
    domains: List.unmodifiable([
      for (final value in (breakdown as List?) ?? const <Object?>[])
        _domain(attemptJsonMap(value, 'domain_breakdown[]')),
    ]),
  );
}

DomainScore _domain(Map<String, Object?> json) {
  final correct = attemptJsonInt(json, 'correct');
  final total = attemptJsonInt(json, 'total');
  if (correct > total) throw const FormatException('correct');
  return DomainScore(
    domain: attemptJsonString(json, 'domain'),
    correct: correct,
    total: total,
  );
}
