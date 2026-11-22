import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/teacher/videos/domain/entities/video_upload.dart';

/// Server calls of the upload flow (`docs/07`). Quota and delete live on
/// `TeacherVideosRepository`.
abstract interface class VideoUploadRepository {
  Future<Result<VideoUploadLimits>> limits();

  /// Reserves a pending asset. `quota_exceeded` comes back as a Failure.
  Future<Result<String>> createAsset({
    required String topicId,
    required String? subtopicId,
    required String title,
    required int durationS,
    required int sizeMb,
  });

  /// Presigned PUT URLs by file name.
  Future<Result<Map<String, String>>> uploadUrls(
    String assetId,
    List<String> files,
  );

  Future<Result<void>> confirm(String assetId, String keyHex);
}
