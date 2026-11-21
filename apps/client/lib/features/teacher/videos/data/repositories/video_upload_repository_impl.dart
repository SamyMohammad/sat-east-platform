import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/teacher/videos/data/datasources/video_upload_remote_data_source.dart';
import 'package:sat_east_client/features/teacher/videos/domain/entities/video_upload.dart';
import 'package:sat_east_client/features/teacher/videos/domain/repositories/video_upload_repository.dart';

class VideoUploadRepositoryImpl implements VideoUploadRepository {
  VideoUploadRepositoryImpl(this._source);
  final VideoUploadRemoteDataSource _source;

  @override
  Future<Result<VideoUploadLimits>> limits() => _source.limits();

  @override
  Future<Result<String>> createAsset({
    required String topicId,
    required String? subtopicId,
    required String title,
    required int durationS,
    required int sizeMb,
  }) => _source.createAsset(
    topicId: topicId,
    subtopicId: subtopicId,
    title: title,
    durationS: durationS,
    sizeMb: sizeMb,
  );

  @override
  Future<Result<Map<String, String>>> uploadUrls(
    String assetId,
    List<String> files,
  ) => _source.uploadUrls(assetId, files);

  @override
  Future<Result<void>> confirm(String assetId, String keyHex) =>
      _source.confirm(assetId, keyHex);
}
