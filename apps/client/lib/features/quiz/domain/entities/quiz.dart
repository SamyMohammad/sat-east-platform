import 'package:equatable/equatable.dart';
import 'package:sat_east_client/core/attempts/attempt_question.dart';
import 'package:sat_east_client/core/attempts/skill_result.dart';

export 'package:sat_east_client/core/attempts/attempt_question.dart'
    show SavedAnswer;
export 'package:sat_east_client/core/attempts/save_outcome.dart';

typedef QuizKind = AttemptKind;
typedef QuizChoice = AttemptChoice;
typedef QuizQuestion = AttemptQuestion;

class QuizSession extends Equatable {
  const QuizSession({
    required this.attemptId,
    required this.title,
    required this.timeLimit,
    required this.deadline,
    required this.serverNow,
    required this.warnAt,
    required this.questions,
    required this.answers,
    required this.clientSeq,
  });

  final String attemptId;
  final String title;
  final Duration timeLimit;
  final DateTime deadline;
  final DateTime serverNow;
  final Duration warnAt;
  final List<QuizQuestion> questions;
  final Map<String, SavedAnswer> answers;
  final int clientSeq;

  @override
  List<Object?> get props => [
    attemptId,
    title,
    timeLimit,
    deadline,
    serverNow,
    warnAt,
    questions,
    answers,
    clientSeq,
  ];
}

class QuizReport extends Equatable {
  const QuizReport({
    required this.attemptId,
    required this.scoreRaw,
    required this.scoreTotal,
    required this.scorePct,
    required this.passMark,
    required this.passed,
    required this.nextTopic,
    required this.retakeAt,
    this.skills = const [],
    this.nextNeedsAccess = false,
  });

  final String attemptId;
  final int scoreRaw;
  final int scoreTotal;
  final double scorePct;
  final int passMark;
  final bool passed;
  final ({String id, String title})? nextTopic;
  final DateTime? retakeAt;
  final List<SkillResult> skills;

  /// The student has no enrolment and the next topic is not free (CRS-06).
  final bool nextNeedsAccess;

  @override
  List<Object?> get props => [
    attemptId,
    scoreRaw,
    scoreTotal,
    scorePct,
    passMark,
    passed,
    nextTopic,
    retakeAt,
    skills,
    nextNeedsAccess,
  ];
}
