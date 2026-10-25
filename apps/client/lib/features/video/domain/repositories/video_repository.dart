import 'package:sat_east_client/core/errors/result.dart';

import 'package:sat_east_client/features/video/domain/entities/video_playback.dart';
import 'package:sat_east_client/features/video/domain/entities/video_settings.dart';
import 'package:sat_east_client/features/video/domain/entities/watched_span.dart';

abstract interface class VideoRepository {
  Future<Result<VideoPlayback>> requestPlayback(String assetId);
  Future<Result<({int pct, bool done})>> saveProgress(
    String assetId,
    WatchedSpan span,
    int positionS,
  );
  Future<Result<VideoSettings>> loadSettings();
}
