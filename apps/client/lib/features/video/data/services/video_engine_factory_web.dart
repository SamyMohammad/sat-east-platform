import 'package:sat_east_client/core/video/video_provider.dart';
import 'package:sat_east_client/features/video/data/services/hls_web_engine.dart';
import 'package:sat_east_client/features/video/data/services/youtube_web_engine.dart';
import 'package:sat_east_client/features/video/domain/services/video_engine.dart';

VideoEngine createVideoEngine(VideoProvider provider) => switch (provider) {
  VideoProvider.r2Hls => HlsWebEngine(),
  VideoProvider.youtube => YoutubeWebEngine(),
};
