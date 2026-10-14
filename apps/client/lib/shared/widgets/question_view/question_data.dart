import 'package:flutter/foundation.dart';

enum QuestionDifficulty { easy, medium, hard }

/// One MCQ choice. [md] is `MathText` markup.
@immutable
final class ChoiceData {
  const ChoiceData({required this.label, required this.md});

  final String label;
  final String md;
}

sealed class QuestionKind {
  const QuestionKind();
}

final class McqKind extends QuestionKind {
  const McqKind(this.choices);

  final List<ChoiceData> choices;
}

final class SprKind extends QuestionKind {
  const SprKind();
}

/// What the student may see before submitting. Carries no answer key,
/// explanation or misconception (rule 1).
@immutable
final class QuestionData {
  const QuestionData({
    required this.id,
    required this.label,
    required this.stemMd,
    required this.kind,
    this.imagePaths = const [],
    this.difficulty,
    this.skill,
  });

  final String id;

  /// Exercise label, e.g. "4.2 · Ex 7".
  final String label;

  /// `MathText` markup.
  final String stemMd;
  final QuestionKind kind;
  final List<String> imagePaths;
  final QuestionDifficulty? difficulty;
  final String? skill;
}
