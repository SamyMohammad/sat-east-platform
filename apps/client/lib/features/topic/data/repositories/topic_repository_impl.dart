import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/topic/data/datasources/topic_remote_data_source.dart';
import 'package:sat_east_client/features/topic/domain/entities/topic_detail.dart';
import 'package:sat_east_client/features/topic/domain/repositories/topic_repository.dart';

class TopicRepositoryImpl implements TopicRepository {
  TopicRepositoryImpl(this._remote);

  final TopicRemoteDataSource _remote;

  @override
  Future<Result<TopicDetail>> getTopic(String topicId) =>
      _remote.getTopic(topicId);
}
