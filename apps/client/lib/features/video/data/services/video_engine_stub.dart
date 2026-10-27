import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/core/video/video_provider.dart';
import 'package:sat_east_client/features/video/domain/entities/video_playback.dart';
import 'package:sat_east_client/features/video/domain/services/video_engine.dart';

VideoEngine createVideoEngine(VideoProvider provider) =>
    const VideoEngineStub();

class VideoEngineStub implements VideoEngine {
  const VideoEngineStub();

  @override
  String get viewType => 'unsupported-video';
  @override
  Stream<double> get position => const Stream.empty();
  @override
  Stream<EngineStatus> get status => const Stream.empty();
  @override
  Stream<AppError> get fatalErrors => const Stream.empty();
  @override
  double? get durationS => null;
  @override
  Future<Result<void>> attach(VideoPlayback playback) async =>
      const Failure(AppError(ErrorCodes.unsupported));
  @override
  void play() {}
  @override
  void pause() {}
  @override
  void seek(double s) {}
  @override
  void setRate(double r) {}
  @override
  Future<void> requestFullscreen() async {}
  @override
  Future<void> exitFullscreen() async {}
  @override
  Future<void> dispose() async {}
}
