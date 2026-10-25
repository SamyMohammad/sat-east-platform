import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/teacher/videos/domain/entities/teacher_video.dart';
import 'package:sat_east_client/features/teacher/videos/domain/entities/video_quota.dart';

abstract interface class TeacherVideosRepository {
  Future<Result<List<TeacherVideo>>> list(String topicId);
  Future<Result<VideoQuota>> quota();
  Future<Result<void>> addYoutube(
    String topicId,
    String title,
    String youtubeId,
    int durationS,
  );
  Future<Result<void>> update(String assetId, String title, String? subtopicId);
  Future<Result<void>> reorder(String topicId, List<String> ids);
  Future<Result<void>> delete(String assetId);
}
