import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/video/data/datasources/video_remote_data_source.dart';
import 'package:sat_east_client/features/video/domain/entities/video_playback.dart';
import 'package:sat_east_client/features/video/domain/entities/video_settings.dart';
import 'package:sat_east_client/features/video/domain/entities/watched_span.dart';
import 'package:sat_east_client/features/video/domain/repositories/video_repository.dart';

class VideoRepositoryImpl implements VideoRepository {
  VideoRepositoryImpl(this._remote);

  final VideoRemoteDataSource _remote;

  @override
  Future<Result<VideoPlayback>> requestPlayback(String assetId) =>
      _remote.requestPlayback(assetId);

  @override
  Future<Result<({int pct, bool done})>> saveProgress(
    String assetId,
    WatchedSpan span,
    int positionS,
  ) => _remote.saveProgress(assetId, span, positionS);

  @override
  Future<Result<VideoSettings>> loadSettings() => _remote.loadSettings();
}
