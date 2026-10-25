import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/video/domain/entities/video_playback.dart';

enum EngineStatus { idle, loading, playing, paused, buffering, ended }

abstract interface class VideoEngine {
  String get viewType;
  Stream<double> get position;
  Stream<EngineStatus> get status;
  Stream<AppError> get fatalErrors;
  double? get durationS;
  Future<Result<void>> attach(VideoPlayback playback);
  void play();
  void pause();
  void seek(double s);
  void setRate(double r);
  Future<void> requestFullscreen();
  Future<void> exitFullscreen();
  Future<void> dispose();
}

/// Browser Escape can exit fullscreen without invoking our controls.
abstract interface class FullscreenVideoEngine {
  Stream<bool> get fullscreenChanges;
}
