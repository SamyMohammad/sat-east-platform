import 'package:equatable/equatable.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/homework/domain/entities/homework.dart';

sealed class HomeworkState extends Equatable {
  const HomeworkState();
  @override
  List<Object?> get props => const [];
}

final class HomeworkLoading extends HomeworkState {
  const HomeworkLoading();
}

final class HomeworkFailed extends HomeworkState {
  const HomeworkFailed(this.error);
  final AppError error;
  @override
  List<Object?> get props => [error];
}

final class HomeworkSubmitted extends HomeworkState {
  const HomeworkSubmitted(this.report);
  final HomeworkReport report;
  @override
  List<Object?> get props => [report];
}

final class HomeworkRunning extends HomeworkState {
  const HomeworkRunning({
    required this.session,
    this.index = 0,
    this.answers = const {},
    this.marked = const {},
    this.eliminated = const {},
    this.saving = false,
    this.submitting = false,
    this.saveError,
    this.submitError,
  });
  final HomeworkSession session;
  final int index;
  final Map<String, String?> answers;
  final Set<String> marked;
  final Map<String, Set<String>> eliminated;
  final bool saving;
  final bool submitting;
  final AppError? saveError;
  final AppError? submitError;
  HomeworkRunning copyWith({
    int? index,
    Map<String, String?>? answers,
    Set<String>? marked,
    Map<String, Set<String>>? eliminated,
    bool? saving,
    bool? submitting,
    AppError? saveError,
    AppError? submitError,
    bool clearSaveError = false,
    bool clearSubmitError = false,
  }) => HomeworkRunning(
    session: session,
    index: index ?? this.index,
    answers: answers ?? this.answers,
    marked: marked ?? this.marked,
    eliminated: eliminated ?? this.eliminated,
    saving: saving ?? this.saving,
    submitting: submitting ?? this.submitting,
    saveError: clearSaveError ? null : saveError ?? this.saveError,
    submitError: clearSubmitError ? null : submitError ?? this.submitError,
  );
  @override
  List<Object?> get props => [
    session,
    index,
    answers,
    marked,
    eliminated,
    saving,
    submitting,
    saveError,
    submitError,
  ];
}
