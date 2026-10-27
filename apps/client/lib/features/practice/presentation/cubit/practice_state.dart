import 'package:equatable/equatable.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/practice/domain/entities/practice.dart';
import 'package:sat_east_client/shared/widgets/question_view/rep_outcome.dart';

sealed class PracticeState extends Equatable {
  const PracticeState();

  @override
  List<Object?> get props => const [];
}

final class PracticeLoading extends PracticeState {
  const PracticeLoading();
}

final class PracticeFailed extends PracticeState {
  const PracticeFailed(this.error);

  final AppError error;

  @override
  List<Object?> get props => [error];
}

final class PracticeInProgress extends PracticeState {
  const PracticeInProgress({
    required this.set,
    required this.index,
    this.selected,
    this.sprText = '',
    this.feedback = const Answering(),
    this.firstTry,
    this.checkError,
    this.outcomes = const [],
  });

  final PracticeSet set;
  final int index;
  final String? selected;
  final String sprText;
  final PracticeStep feedback;
  final String? firstTry;
  final AppError? checkError;

  /// Outcome i belongs to rep i, for the reps answered in this session.
  final List<RepOutcome> outcomes;

  @override
  List<Object?> get props => [
    set,
    index,
    selected,
    sprText,
    feedback,
    firstTry,
    checkError,
    outcomes,
  ];
}

final class PracticeSummary extends PracticeState {
  const PracticeSummary({required this.correctFirstTry, required this.total});

  final int correctFirstTry;
  final int total;

  @override
  List<Object?> get props => [correctFirstTry, total];
}

sealed class PracticeStep extends Equatable {
  const PracticeStep();

  @override
  List<Object?> get props => const [];
}

final class Answering extends PracticeStep {
  const Answering();
}

final class Checking extends PracticeStep {
  const Checking();
}

final class MissedOnce extends PracticeStep {
  const MissedOnce({required this.missed, this.hintMd, this.misconceptionMd});

  final String missed;
  final String? hintMd;
  final String? misconceptionMd;

  @override
  List<Object?> get props => [missed, hintMd, misconceptionMd];
}

final class Done extends PracticeStep {
  const Done(this.result);

  final CheckResult result;

  @override
  List<Object?> get props => [result];
}
