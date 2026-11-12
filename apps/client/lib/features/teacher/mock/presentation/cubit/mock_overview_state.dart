import 'package:equatable/equatable.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/teacher/mock/domain/entities/mock_entities.dart';

sealed class MockOverviewState extends Equatable {
  const MockOverviewState();
  @override
  List<Object?> get props => const [];
}

final class MockOverviewLoading extends MockOverviewState {
  const MockOverviewLoading();
}

/// The teacher has no SAT course, so no mock RPC is called.
final class MockOverviewNoCourse extends MockOverviewState {
  const MockOverviewNoCourse();
}

final class MockOverviewLoaded extends MockOverviewState {
  const MockOverviewLoaded({
    required this.courseId,
    required this.overview,
    this.busy = false,
    this.lastError,
    this.lastShortage,
  });
  final String courseId;
  final MockOverview overview;
  final bool busy;
  final AppError? lastError;

  /// Set when the last assemble found the reserve bank short.
  final Shortage? lastShortage;

  MockOverviewLoaded copyWith({
    MockOverview? overview,
    bool? busy,
    AppError? lastError,
    Shortage? lastShortage,
  }) => MockOverviewLoaded(
    courseId: courseId,
    overview: overview ?? this.overview,
    busy: busy ?? this.busy,
    lastError: lastError,
    lastShortage: lastShortage,
  );

  @override
  List<Object?> get props => [
    courseId,
    overview,
    busy,
    lastError,
    lastShortage,
  ];
}

final class MockOverviewFailed extends MockOverviewState {
  const MockOverviewFailed(this.error);
  final AppError error;
  @override
  List<Object?> get props => [error];
}
