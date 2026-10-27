import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/teacher/videos/data/datasources/teacher_videos_remote_data_source.dart';
import 'package:sat_east_client/features/teacher/videos/domain/entities/teacher_video.dart';
import 'package:sat_east_client/features/teacher/videos/domain/entities/video_quota.dart';
import 'package:sat_east_client/features/teacher/videos/domain/repositories/teacher_videos_repository.dart';

class TeacherVideosRepositoryImpl implements TeacherVideosRepository {
  TeacherVideosRepositoryImpl(this._source);
  final TeacherVideosRemoteDataSource _source;
  @override
  Future<Result<List<TeacherVideo>>> list(String topicId) =>
      _source.list(topicId);
  @override
  Future<Result<VideoQuota>> quota() => _source.quota();
  @override
  Future<Result<void>> addYoutube(
    String topicId,
    String title,
    String youtubeId,
    int durationS,
  ) => _source.addYoutube(topicId, title, youtubeId, durationS);
  @override
  Future<Result<void>> update(
    String assetId,
    String title,
    String? subtopicId,
  ) => _source.update(assetId, title, subtopicId);
  @override
  Future<Result<void>> reorder(String topicId, List<String> ids) =>
      _source.reorder(topicId, ids);
  @override
  Future<Result<void>> delete(String assetId) => _source.delete(assetId);
}
