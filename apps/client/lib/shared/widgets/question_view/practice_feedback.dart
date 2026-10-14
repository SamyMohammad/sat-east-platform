sealed class AnswerKey {
  const AnswerKey();
}

final class McqAnswerKey extends AnswerKey {
  const McqAnswerKey(this.label);

  final String label;
}

/// Named `SprAnswerKey` because `SprKey` is taken by `core/grading`.
final class SprAnswerKey extends AnswerKey {
  const SprAnswerKey(this.text);

  final String text;
}

/// Server result of a practice check (rule 1); the widget never grades.
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
}

final class Correct extends PracticeFeedback {
  const Correct({this.noteMd, this.explanationMd, this.firstTry});

  final String? noteMd;
  final String? explanationMd;
  final String? firstTry;
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
}
