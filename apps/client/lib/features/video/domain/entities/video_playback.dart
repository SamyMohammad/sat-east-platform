sealed class VideoPlayback {
  const VideoPlayback({required this.resumeS});

  final int resumeS;
}

final class HlsPlayback extends VideoPlayback {
  const HlsPlayback({
    required this.hlsUrl,
    required this.expiresAt,
    required this.watermarkName,
    required this.watermarkShortId,
    required super.resumeS,
  });

  final String hlsUrl;
  final DateTime expiresAt;
  final String watermarkName;
  final String watermarkShortId;

  String get watermarkText => '$watermarkName \u00b7 $watermarkShortId';
}

final class YoutubePlayback extends VideoPlayback {
  const YoutubePlayback({required this.youtubeId, required super.resumeS});

  final String youtubeId;
}
