import 'package:equatable/equatable.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/mock/domain/entities/mock_entities.dart';

sealed class MockExamState extends Equatable {
  const MockExamState();

  @override
  List<Object?> get props => const [];
}

final class MockExamLoading extends MockExamState {
  const MockExamLoading();
}

final class MockExamFailed extends MockExamState {
  const MockExamFailed(this.error);

  final AppError error;

  @override
  List<Object?> get props => [error];
}

/// A running module. Answers hold the choice label or the typed SPR text.
final class MockExamModule extends MockExamState {
  const MockExamModule({
    required this.module,
    required this.remaining,
    this.index = 0,
    this.answers = const {},
    this.marked = const {},
    this.eliminated = const {},
    this.timerHidden = false,
    this.reviewOpen = false,
    this.submitting = false,
    this.saveError,
    this.submitError,
  });

  final MockModule module;
  final int index;
  final Map<String, String?> answers;
  final Set<String> marked;

  /// Struck-out choice labels per question id.
  final Map<String, Set<String>> eliminated;
  final Duration remaining;
  final bool timerHidden;
  final bool reviewOpen;
  final bool submitting;
  final AppError? saveError;
  final AppError? submitError;

  MockExamModule copyWith({
    int? index,
    Map<String, String?>? answers,
    Set<String>? marked,
    Map<String, Set<String>>? eliminated,
    Duration? remaining,
    bool? timerHidden,
    bool? reviewOpen,
    bool? submitting,
    AppError? saveError,
    AppError? submitError,
    bool clearSaveError = false,
    bool clearSubmitError = false,
  }) => MockExamModule(
    module: module,
    index: index ?? this.index,
    answers: answers ?? this.answers,
    marked: marked ?? this.marked,
    eliminated: eliminated ?? this.eliminated,
    remaining: remaining ?? this.remaining,
    timerHidden: timerHidden ?? this.timerHidden,
    reviewOpen: reviewOpen ?? this.reviewOpen,
    submitting: submitting ?? this.submitting,
    saveError: clearSaveError ? null : saveError ?? this.saveError,
    submitError: clearSubmitError ? null : submitError ?? this.submitError,
  );

  @override
  List<Object?> get props => [
    module,
    index,
    answers,
    marked,
    eliminated,
    remaining,
    timerHidden,
    reviewOpen,
    submitting,
    saveError,
    submitError,
  ];
}

/// The break between modules; [remaining] counts down to [gapUntil].
final class MockExamGap extends MockExamState {
  const MockExamGap({
    required this.groupId,
    required this.gapUntil,
    required this.remaining,
    this.startingModule2 = false,
    this.error,
  });

  final String groupId;
  final DateTime gapUntil;
  final Duration remaining;
  final bool startingModule2;

  /// The last failed attempt to start module 2.
  final AppError? error;

  MockExamGap copyWith({
    Duration? remaining,
    bool? startingModule2,
    AppError? error,
    bool clearError = false,
  }) => MockExamGap(
    groupId: groupId,
    gapUntil: gapUntil,
    remaining: remaining ?? this.remaining,
    startingModule2: startingModule2 ?? this.startingModule2,
    error: clearError ? null : error ?? this.error,
  );

  @override
  List<Object?> get props => [
    groupId,
    gapUntil,
    remaining,
    startingModule2,
    error,
  ];
}

/// The run is over. While both [result] and [resultError] are null the score
/// row is loading.
final class MockExamFinished extends MockExamState {
  const MockExamFinished({
    required this.resultId,
    this.result,
    this.resultError,
  });

  final String resultId;
  final MockResult? result;
  final AppError? resultError;

  bool get loading => result == null && resultError == null;

  @override
  List<Object?> get props => [resultId, result, resultError];
}
