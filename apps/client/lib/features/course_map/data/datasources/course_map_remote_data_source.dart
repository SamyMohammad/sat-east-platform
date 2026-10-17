import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/core/errors/supabase_error_mapper.dart';
import 'package:sat_east_client/core/supabase/rpc_caller.dart';
import 'package:sat_east_client/features/course_map/data/models/course_map_model.dart';
import 'package:sat_east_client/features/course_map/domain/entities/course_map.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _malformed = AppError(ErrorCodes.internal, 'malformed rpc payload');

/// `get_course_map` RPC.
class CourseMapRemoteDataSource {
  CourseMapRemoteDataSource(this._rpc);

  final RpcCaller _rpc;

  Future<Result<CourseMap>> getCourseMap({String? slug}) async {
    try {
      final raw = await _rpc('get_course_map', {
        'p_slug': ?slug,
      });
      if (raw is! Map) return const Failure(_malformed);
      return Success(courseMapFromJson(raw.cast<String, Object?>()));
    } on PostgrestException catch (e) {
      return Failure(mapPostgrestException(e));
    } on FormatException {
      return const Failure(_malformed);
    } on Object catch (e) {
      return Failure(mapUnknownError(e));
    }
  }
}
