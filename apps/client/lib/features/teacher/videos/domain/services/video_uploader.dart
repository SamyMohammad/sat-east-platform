import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/teacher/videos/domain/entities/video_upload.dart';

/// PUTs packaged files to presigned URLs.
abstract interface class VideoUploader {
  /// [urls] maps file name to its presigned URL. Completes only after every
  /// in-flight request has finished, so a rollback can safely delete the
  /// prefix. Failure codes: `video_upload_failed`, `network`, `cancelled`.
  Future<Result<void>> upload(
    List<HlsFile> files,
    Map<String, String> urls, {
    void Function(int done, int total)? onProgress,
  });

  /// Stops starting new requests; [upload] then completes with `cancelled`.
  void cancel();
}
