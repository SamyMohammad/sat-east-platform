import 'package:flutter/foundation.dart';

@immutable
sealed class AnswerKey {
  const AnswerKey();
}

final class McqAnswerKey extends AnswerKey {
  const McqAnswerKey(this.label);

  final String label;

  @override
  bool operator ==(Object other) =>
      other is McqAnswerKey && other.label == label;

  @override
  int get hashCode => label.hashCode;
}

/// Named `SprAnswerKey` because `SprKey` is taken by `core/grading`.
final class SprAnswerKey extends AnswerKey {
  const SprAnswerKey(this.text);

  final String text;

  @override
  bool operator ==(Object other) => other is SprAnswerKey && other.text == text;

  @override
  int get hashCode => text.hashCode;
}

/// Server result of a practice check (rule 1); the widget never grades.
///
/// Value equality: screens rebuild these on every tap, and the dock must not
/// replay its reveal for an unchanged verdict.
@immutable
sealed class PracticeFeedback {
  const PracticeFeedback();
}

final class Idle extends PracticeFeedback {
  const Idle();
}

final class Checking extends PracticeFeedback {
  const Checking();
}

final class FirstMiss extends PracticeFeedback {
  const FirstMiss({required this.missed, this.noteMd, this.hintMd});

  /// MCQ label or SPR text of the first try.
  final String missed;
  final String? noteMd;
  final String? hintMd;

  @override
  bool operator ==(Object other) =>
      other is FirstMiss &&
      other.missed == missed &&
      other.noteMd == noteMd &&
      other.hintMd == hintMd;

  @override
  int get hashCode => Object.hash(missed, noteMd, hintMd);
}

final class Correct extends PracticeFeedback {
  const Correct({this.noteMd, this.explanationMd, this.firstTry});

  final String? noteMd;
  final String? explanationMd;
  final String? firstTry;

  @override
  bool operator ==(Object other) =>
      other is Correct &&
      other.noteMd == noteMd &&
      other.explanationMd == explanationMd &&
      other.firstTry == firstTry;

  @override
  int get hashCode => Object.hash(noteMd, explanationMd, firstTry);
}

final class Revealed extends PracticeFeedback {
  const Revealed({
    required this.key,
    required this.firstTry,
    this.noteMd,
    this.explanationMd,
  });

  final AnswerKey key;
  final String firstTry;
  final String? noteMd;
  final String? explanationMd;

  @override
  bool operator ==(Object other) =>
      other is Revealed &&
      other.key == key &&
      other.firstTry == firstTry &&
      other.noteMd == noteMd &&
      other.explanationMd == explanationMd;

  @override
  int get hashCode => Object.hash(key, firstTry, noteMd, explanationMd);
}
