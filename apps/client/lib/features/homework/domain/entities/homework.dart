import 'package:equatable/equatable.dart';
import 'package:sat_east_client/core/attempts/attempt_question.dart';

class HomeworkSession extends Equatable {
  const HomeworkSession({
    required this.attemptId,
    required this.title,
    required this.questions,
    required this.answers,
    required this.clientSeq,
  });
  final String attemptId;
  final String title;
  final List<AttemptQuestion> questions;
  final Map<String, SavedAnswer> answers;
  final int clientSeq;
  @override
  List<Object?> get props => [attemptId, title, questions, answers, clientSeq];
}

class HomeworkReport extends Equatable {
  const HomeworkReport({
    required this.attemptId,
    required this.scoreRaw,
    required this.scoreTotal,
    required this.scorePct,
  });
  final String attemptId;
  final int scoreRaw;
  final int scoreTotal;
  final double scorePct;
  @override
  List<Object?> get props => [attemptId, scoreRaw, scoreTotal, scorePct];
}
