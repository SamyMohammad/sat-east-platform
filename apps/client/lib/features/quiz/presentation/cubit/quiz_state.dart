import 'package:equatable/equatable.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/quiz/domain/entities/quiz.dart';

sealed class QuizState extends Equatable {
  const QuizState();

  @override
  List<Object?> get props => const [];
}

final class QuizLoading extends QuizState {
  const QuizLoading();
}

final class QuizFailed extends QuizState {
  const QuizFailed(this.error);

  final AppError error;

  @override
  List<Object?> get props => [error];
}

final class QuizRunning extends QuizState {
  const QuizRunning({
    required this.session,
    required this.remaining,
    this.index = 0,
    this.answers = const {},
    this.marked = const {},
    this.timerHidden = false,
    this.saveError,
    this.submitError,
    this.submitting = false,
  });

  final QuizSession session;
  final int index;
  final Map<String, String?> answers;
  final Set<String> marked;
  final Duration remaining;
  final bool timerHidden;
  final AppError? saveError;
  final AppError? submitError;
  final bool submitting;

  QuizRunning copyWith({
    int? index,
    Map<String, String?>? answers,
    Set<String>? marked,
    Duration? remaining,
    bool? timerHidden,
    AppError? saveError,
    AppError? submitError,
    bool? submitting,
    bool clearSaveError = false,
    bool clearSubmitError = false,
  }) => QuizRunning(
    session: session,
    index: index ?? this.index,
    answers: answers ?? this.answers,
    marked: marked ?? this.marked,
    remaining: remaining ?? this.remaining,
    timerHidden: timerHidden ?? this.timerHidden,
    saveError: clearSaveError ? null : saveError ?? this.saveError,
    submitError: clearSubmitError ? null : submitError ?? this.submitError,
    submitting: submitting ?? this.submitting,
  );

  @override
  List<Object?> get props => [
    session,
    index,
    answers,
    marked,
    remaining,
    timerHidden,
    saveError,
    submitError,
    submitting,
  ];
}

final class QuizSubmitted extends QuizState {
  const QuizSubmitted(this.report);

  final QuizReport report;

  @override
  List<Object?> get props => [report];
}
