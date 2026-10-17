import 'package:equatable/equatable.dart';

enum QuizKind { mcq, spr }

enum SaveOutcome { saved, stale }

class QuizChoice extends Equatable {
  const QuizChoice(this.label, this.bodyMd);

  final String label;
  final String bodyMd;

  @override
  List<Object?> get props => [label, bodyMd];
}

class QuizQuestion extends Equatable {
  const QuizQuestion({
    required this.id,
    required this.kind,
    required this.difficulty,
    required this.stemMd,
    required this.choices,
  });

  final String id;
  final QuizKind kind;
  final String difficulty;
  final String stemMd;
  final List<QuizChoice> choices;

  @override
  List<Object?> get props => [id, kind, difficulty, stemMd, choices];
}

class SavedAnswer extends Equatable {
  const SavedAnswer({required this.marked, this.answer});

  final String? answer;
  final bool marked;

  @override
  List<Object?> get props => [answer, marked];
}

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
    required this.scoreRaw,
    required this.scoreTotal,
    required this.scorePct,
    required this.passMark,
    required this.passed,
    required this.nextTopic,
    required this.retakeAt,
  });

  final int scoreRaw;
  final int scoreTotal;
  final double scorePct;
  final int passMark;
  final bool passed;
  final ({String id, String title})? nextTopic;
  final DateTime? retakeAt;

  @override
  List<Object?> get props => [
    scoreRaw,
    scoreTotal,
    scorePct,
    passMark,
    passed,
    nextTopic,
    retakeAt,
  ];
}
