import 'package:equatable/equatable.dart';

enum AttemptKind { mcq, spr }

class AttemptChoice extends Equatable {
  const AttemptChoice(this.label, this.bodyMd);

  final String label;
  final String bodyMd;

  @override
  List<Object?> get props => [label, bodyMd];
}

class AttemptQuestion extends Equatable {
  const AttemptQuestion({
    required this.id,
    required this.kind,
    required this.difficulty,
    required this.stemMd,
    required this.choices,
  });

  final String id;
  final AttemptKind kind;
  final String difficulty;
  final String stemMd;
  final List<AttemptChoice> choices;

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
