import 'package:equatable/equatable.dart';
import 'package:sat_east_client/features/video/domain/entities/video_playback.dart';
import 'package:sat_east_client/features/video/domain/services/video_engine.dart';

sealed class VideoPlayerState extends Equatable {
  const VideoPlayerState();
  @override
  List<Object?> get props => [];
}

final class VideoPlayerLoading extends VideoPlayerState {
  const VideoPlayerLoading({this.viewType});
  final String? viewType;
  @override
  List<Object?> get props => [viewType];
}

final class VideoPlayerError extends VideoPlayerState {
  const VideoPlayerError(this.code);
  final String code;
  @override
  List<Object?> get props => [code];
}

final class VideoPlayerReady extends VideoPlayerState {
  const VideoPlayerReady({
    required this.playback,
    required this.status,
    required this.positionS,
    required this.durationS,
    required this.rate,
    required this.fullscreen,
    required this.done,
    required this.watermarkMoveS,
  });
  final VideoPlayback playback;
  final EngineStatus status;
  final double positionS;
  final double? durationS;
  final double rate;
  final bool fullscreen;
  final bool done;
  final int watermarkMoveS;

  VideoPlayerReady copyWith({
    VideoPlayback? playback,
    EngineStatus? status,
    double? positionS,
    double? durationS,
    double? rate,
    bool? fullscreen,
    bool? done,
  }) => VideoPlayerReady(
    playback: playback ?? this.playback,
    status: status ?? this.status,
    positionS: positionS ?? this.positionS,
    durationS: durationS ?? this.durationS,
    rate: rate ?? this.rate,
    fullscreen: fullscreen ?? this.fullscreen,
    done: done ?? this.done,
    watermarkMoveS: watermarkMoveS,
  );

  @override
  List<Object?> get props => [
    playback,
    status,
    positionS,
    durationS,
    rate,
    fullscreen,
    done,
    watermarkMoveS,
  ];
}
