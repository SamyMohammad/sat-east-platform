import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/topic/domain/entities/topic_detail.dart';

// Domain port for the topic RPC, matching the other feature repositories.
// ignore: one_member_abstracts
abstract interface class TopicRepository {
  Future<Result<TopicDetail>> getTopic(String topicId);
}
