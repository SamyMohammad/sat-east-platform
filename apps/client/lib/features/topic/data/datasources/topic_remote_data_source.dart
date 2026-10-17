import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/core/errors/supabase_error_mapper.dart';
import 'package:sat_east_client/core/supabase/rpc_caller.dart';
import 'package:sat_east_client/features/topic/data/models/topic_model.dart';
import 'package:sat_east_client/features/topic/domain/entities/topic_detail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _malformed = AppError(ErrorCodes.internal, 'malformed rpc payload');

class TopicRemoteDataSource {
  TopicRemoteDataSource(this._rpc);

  final RpcCaller _rpc;

  Future<Result<TopicDetail>> getTopic(String topicId) async {
    try {
      final raw = await _rpc('get_topic', {'p_topic_id': topicId});
      if (raw is! Map) return const Failure(_malformed);
      return Success(topicDetailFromJson(raw.cast<String, Object?>()));
    } on PostgrestException catch (e) {
      return Failure(mapPostgrestException(e));
    } on FormatException {
      return const Failure(_malformed);
    } on Object catch (e) {
      return Failure(mapUnknownError(e));
    }
  }
}
