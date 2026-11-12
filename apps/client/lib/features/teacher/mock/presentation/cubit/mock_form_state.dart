import 'package:equatable/equatable.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/teacher/mock/domain/entities/mock_entities.dart';
import 'package:sat_east_client/features/teacher/questions/domain/entities/question_draft.dart';

sealed class MockFormState extends Equatable {
  const MockFormState();
  @override
  List<Object?> get props => const [];
}

final class MockFormLoading extends MockFormState {
  const MockFormLoading();
}

/// The form (or the SAT course) does not exist: a deleted draft, a stale
/// link or an invalid URL.
final class MockFormMissing extends MockFormState {
  const MockFormMissing();
}

final class MockFormFailed extends MockFormState {
  const MockFormFailed(this.error);
  final AppError error;
  @override
  List<Object?> get props => [error];
}

const Object _keep = Object();

final class MockFormLoaded extends MockFormState {
  const MockFormLoaded(
    this.form, {
    this.stale = const {},
    this.previewId,
    this.preview,
    this.previewError,
    this.candidates,
    this.swappingId,
    this.busy = false,
    this.lastError,
  });
  final MockForm form;

  /// Question ids the last publish found out of date.
  final Set<String> stale;

  /// The tapped question; [preview] and [previewError] are both null while
  /// it loads.
  final String? previewId;
  final QuestionDraft? preview;
  final AppError? previewError;

  /// Swap sheet: [swappingId] is the slot's question; [candidates] is null
  /// while they load.
  final List<MockCandidate>? candidates;
  final String? swappingId;
  final bool busy;
  final AppError? lastError;

  bool get isDraft => form.status == MockFormStatus.draft;

  MockFormLoaded copyWith({
    MockForm? form,
    Set<String>? stale,
    Object? previewId = _keep,
    Object? preview = _keep,
    Object? previewError = _keep,
    Object? candidates = _keep,
    Object? swappingId = _keep,
    bool? busy,
    Object? lastError = _keep,
  }) => MockFormLoaded(
    form ?? this.form,
    stale: stale ?? this.stale,
    previewId: identical(previewId, _keep)
        ? this.previewId
        : previewId as String?,
    preview: identical(preview, _keep)
        ? this.preview
        : preview as QuestionDraft?,
    previewError: identical(previewError, _keep)
        ? this.previewError
        : previewError as AppError?,
    candidates: identical(candidates, _keep)
        ? this.candidates
        : candidates as List<MockCandidate>?,
    swappingId: identical(swappingId, _keep)
        ? this.swappingId
        : swappingId as String?,
    busy: busy ?? this.busy,
    lastError: identical(lastError, _keep)
        ? this.lastError
        : lastError as AppError?,
  );

  @override
  List<Object?> get props => [
    form,
    stale,
    previewId,
    preview,
    previewError,
    candidates,
    swappingId,
    busy,
    lastError,
  ];
}
