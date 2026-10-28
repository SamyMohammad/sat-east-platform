import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/core/errors/supabase_error_mapper.dart';
import 'package:sat_east_client/core/supabase/rpc_caller.dart';
import 'package:sat_east_client/features/skills/data/models/skills_overview_model.dart';
import 'package:sat_east_client/features/skills/domain/entities/skills_overview.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _malformed = AppError(ErrorCodes.internal, 'malformed rpc payload');

/// `get_my_skills` RPC.
class SkillsRemoteDataSource {
  SkillsRemoteDataSource(this._rpc, {required this.readTrendMinimum});

  final RpcCaller _rpc;
  final Future<Object?> Function() readTrendMinimum;

  Future<Result<SkillsOverview>> getMySkills(String courseId) async {
    try {
      final raw = await _rpc('get_my_skills', {'p_course_id': courseId});
      if (raw is! Map) return const Failure(_malformed);
      final setting = await readTrendMinimum();
      if (setting is! Map<String, Object?>) return const Failure(_malformed);
      final minimum = setting['value'];
      if (minimum is! int || minimum < 1) return const Failure(_malformed);
      return Success(
        skillsOverviewFromJson(
          raw.cast<String, Object?>(),
          trendMinAnswers: minimum,
        ),
      );
    } on PostgrestException catch (e) {
      return Failure(mapPostgrestException(e));
    } on FormatException {
      return const Failure(_malformed);
    } on Object catch (e) {
      return Failure(mapUnknownError(e));
    }
  }
}
