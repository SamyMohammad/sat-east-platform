import 'package:equatable/equatable.dart';
import 'package:sat_east_client/core/attempts/attempt_question.dart';

class AttemptReview extends Equatable {
  const AttemptReview({
    required this.scoreRaw,
    required this.scoreTotal,
    required this.scorePct,
    required this.keysVisible,
    required this.questions,
    this.passMark,
    this.passed,
  });
  final int scoreRaw;
  final int scoreTotal;
  final double scorePct;
  final bool keysVisible;
  final int? passMark;
  final bool? passed;
  final List<ReviewQuestion> questions;
  @override
  List<Object?> get props => [
    scoreRaw,
    scoreTotal,
    scorePct,
    keysVisible,
    passMark,
    passed,
    questions,
  ];
}

class ReviewQuestion extends Equatable {
  const ReviewQuestion({
    required this.id,
    required this.stemMd,
    required this.choices,
    required this.myAnswer,
    required this.isCorrect,
    required this.timeMs,
    this.key,
    this.explanationMd,
  });
  final String id;
  final String stemMd;
  final List<AttemptChoice> choices;
  final String? myAnswer;
  final bool isCorrect;
  final int timeMs;
  final String? key;
  final String? explanationMd;
  @override
  List<Object?> get props => [
    id,
    stemMd,
    choices,
    myAnswer,
    isCorrect,
    timeMs,
    key,
    explanationMd,
  ];
}
