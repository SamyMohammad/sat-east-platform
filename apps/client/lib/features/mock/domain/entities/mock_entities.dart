import 'package:equatable/equatable.dart';
import 'package:sat_east_client/core/attempts/attempt_question.dart';

enum MockFormState { locked, available, inProgress, finished }

/// One playable form on the hub; [k] is its rank, [need] the topics to pass.
final class MockHubForm extends Equatable {
  const MockHubForm({
    required this.formNo,
    required this.k,
    required this.need,
    required this.state,
  });

  final int formNo;
  final int k;
  final int need;
  final MockFormState state;

  @override
  List<Object?> get props => [formNo, k, need, state];
}

final class MockHub extends Equatable {
  const MockHub({
    required this.passedTopics,
    required this.forms,
    required this.activeGroup,
  });

  final int passedTopics;
  final List<MockHubForm> forms;

  /// The unfinished mock run, if any.
  final String? activeGroup;

  @override
  List<Object?> get props => [passedTopics, forms, activeGroup];
}

/// One running module: questions without keys or difficulty.
final class MockModule extends Equatable {
  const MockModule({
    required this.groupId,
    required this.moduleNo,
    required this.attemptId,
    required this.title,
    required this.timeLimitS,
    required this.deadline,
    required this.serverNow,
    required this.warnS,
    required this.questions,
    required this.answers,
    required this.clientSeq,
  });

  final String groupId;
  final int moduleNo;
  final String attemptId;
  final String title;
  final int timeLimitS;
  final DateTime deadline;
  final DateTime serverNow;
  final int warnS;
  final List<AttemptQuestion> questions;
  final Map<String, SavedAnswer> answers;
  final int clientSeq;

  @override
  List<Object?> get props => [
    groupId,
    moduleNo,
    attemptId,
    title,
    timeLimitS,
    deadline,
    serverNow,
    warnS,
    questions,
    answers,
    clientSeq,
  ];
}

/// Where a run stands: a module, the break between modules, or done.
sealed class MockStage extends Equatable {
  const MockStage();
}

final class MockModuleStage extends MockStage {
  const MockModuleStage(this.module);

  final MockModule module;

  @override
  List<Object?> get props => [module];
}

final class MockGapStage extends MockStage {
  const MockGapStage({
    required this.groupId,
    required this.gapUntil,
    required this.serverNow,
  });

  final String groupId;
  final DateTime gapUntil;
  final DateTime serverNow;

  @override
  List<Object?> get props => [groupId, gapUntil, serverNow];
}

final class MockFinishedStage extends MockStage {
  const MockFinishedStage({required this.groupId, required this.resultId});

  final String groupId;
  final String resultId;

  @override
  List<Object?> get props => [groupId, resultId];
}

/// `submit_attempt` found module [moduleNo] already running and returned no
/// questions: call `session(groupId)` for the payload.
final class MockModuleStartedStage extends MockStage {
  const MockModuleStartedStage({required this.groupId, required this.moduleNo});

  final String groupId;
  final int moduleNo;

  @override
  List<Object?> get props => [groupId, moduleNo];
}

final class DomainScore extends Equatable {
  const DomainScore({
    required this.domain,
    required this.correct,
    required this.total,
  });

  final String domain;
  final int correct;
  final int total;

  @override
  List<Object?> get props => [domain, correct, total];
}

/// The finished mock's score row. The range is null when no estimate exists.
final class MockResult extends Equatable {
  const MockResult({
    required this.id,
    required this.route,
    required this.rawM1,
    required this.rawM2,
    required this.estLow,
    required this.estHigh,
    required this.domains,
  });

  final String id;
  final String route;
  final int rawM1;
  final int rawM2;
  final int? estLow;
  final int? estHigh;
  final List<DomainScore> domains;

  @override
  List<Object?> get props => [
    id,
    route,
    rawM1,
    rawM2,
    estLow,
    estHigh,
    domains,
  ];
}
