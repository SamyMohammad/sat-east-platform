import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/skills/data/datasources/skills_remote_data_source.dart';
import 'package:sat_east_client/features/skills/domain/entities/skills_overview.dart';
import 'package:sat_east_client/features/skills/domain/repositories/skills_repository.dart';

class SkillsRepositoryImpl implements SkillsRepository {
  SkillsRepositoryImpl(this._remote);

  final SkillsRemoteDataSource _remote;

  @override
  Future<Result<SkillsOverview>> load(String courseId) =>
      _remote.getMySkills(courseId);
}
