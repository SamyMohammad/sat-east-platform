import 'package:equatable/equatable.dart';

enum PracticeKind { mcq, spr }

class PracticeChoice extends Equatable {
  const PracticeChoice(this.label, this.bodyMd);

  final String label;
  final String bodyMd;

  @override
  List<Object?> get props => [label, bodyMd];
}

class PracticeQuestion extends Equatable {
  const PracticeQuestion({
    required this.id,
    required this.kind,
    required this.difficulty,
    required this.stemMd,
    required this.choices,
  });

  final String id;
  final PracticeKind kind;
  final String difficulty;
  final String stemMd;
  final List<PracticeChoice> choices;

  @override
  List<Object?> get props => [id, kind, difficulty, stemMd, choices];
}

class PracticeSet extends Equatable {
  const PracticeSet({
    required this.attemptId,
    required this.repTarget,
    required this.questions,
  });

  final String attemptId;
  final int repTarget;
  final List<PracticeQuestion> questions;

  @override
  List<Object?> get props => [attemptId, repTarget, questions];
}

sealed class AnswerReveal extends Equatable {
  const AnswerReveal();
}

final class ChoiceReveal extends AnswerReveal {
  const ChoiceReveal(this.label);

  final String label;

  @override
  List<Object?> get props => [label];
}

final class TextReveal extends AnswerReveal {
  const TextReveal(this.text);

  final String text;

  @override
  List<Object?> get props => [text];
}

sealed class CheckResult extends Equatable {
  const CheckResult();
}

final class CheckCorrect extends CheckResult {
  const CheckCorrect({
    required this.tryNo,
    required this.key,
    required this.explanationMd,
  });

  final int tryNo;
  final AnswerReveal key;
  final String? explanationMd;

  @override
  List<Object?> get props => [tryNo, key, explanationMd];
}

final class CheckMiss extends CheckResult {
  const CheckMiss({this.hintMd, this.misconceptionMd});

  final String? hintMd;
  final String? misconceptionMd;

  @override
  List<Object?> get props => [hintMd, misconceptionMd];
}

final class CheckRevealed extends CheckResult {
  const CheckRevealed({required this.key, required this.explanationMd});

  final AnswerReveal key;
  final String? explanationMd;

  @override
  List<Object?> get props => [key, explanationMd];
}
