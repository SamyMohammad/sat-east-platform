import 'package:equatable/equatable.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/mock/domain/entities/mock_entities.dart';

sealed class MockHubState extends Equatable {
  const MockHubState();

  @override
  List<Object?> get props => const [];
}

final class MockHubLoading extends MockHubState {
  const MockHubLoading();
}

/// The student has no active SAT enrolment, so no mock RPC is called.
final class MockHubNoCourse extends MockHubState {
  const MockHubNoCourse();
}

final class MockHubLoaded extends MockHubState {
  const MockHubLoaded({
    required this.courseId,
    required this.hub,
    this.busy = false,
    this.lastError,
  });

  final String courseId;
  final MockHub hub;

  /// A `start_mock` call is in flight.
  final bool busy;

  /// The last failed start or reload; the old [hub] stays on screen.
  final AppError? lastError;

  MockHubLoaded copyWith({MockHub? hub, bool? busy, AppError? lastError}) =>
      MockHubLoaded(
        courseId: courseId,
        hub: hub ?? this.hub,
        busy: busy ?? this.busy,
        lastError: lastError,
      );

  @override
  List<Object?> get props => [courseId, hub, busy, lastError];
}

final class MockHubFailed extends MockHubState {
  const MockHubFailed(this.error);

  final AppError error;

  @override
  List<Object?> get props => [error];
}
