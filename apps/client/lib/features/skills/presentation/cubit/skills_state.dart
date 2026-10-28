import 'package:equatable/equatable.dart';

import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/skills/domain/entities/skills_overview.dart';

sealed class SkillsState extends Equatable {
  const SkillsState();

  @override
  List<Object?> get props => const [];
}

final class SkillsLoading extends SkillsState {
  const SkillsLoading();
}

final class SkillsLoaded extends SkillsState {
  const SkillsLoaded(this.overview, this.courseId);

  final SkillsOverview overview;
  final String courseId;

  @override
  List<Object?> get props => [overview, courseId];
}

/// The student has no graded answers yet.
final class SkillsEmpty extends SkillsState {
  const SkillsEmpty();
}

final class SkillsFailed extends SkillsState {
  const SkillsFailed(this.error);

  final AppError error;

  @override
  List<Object?> get props => [error];
}
