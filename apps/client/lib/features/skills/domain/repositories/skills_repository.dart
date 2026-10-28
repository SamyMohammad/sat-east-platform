import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/skills/domain/entities/skills_overview.dart';

// A domain port; more skills reads will join it.
// ignore: one_member_abstracts
abstract interface class SkillsRepository {
  /// Loads the skills overview of [courseId].
  Future<Result<SkillsOverview>> load(String courseId);
}
