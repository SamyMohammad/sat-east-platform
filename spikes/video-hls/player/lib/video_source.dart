import 'dart:convert';

import 'package:http/http.dart' as http;

/// What the player needs to start one playback session (ADR-002).
class PlaybackInfo {
  const PlaybackInfo({
    required this.playlistUrl,
    required this.expiresAt,
    required this.watermarkName,
    required this.watermarkShortId,
  });

  final Uri playlistUrl;
  final DateTime expiresAt;
  final String watermarkName;
  final String watermarkShortId;
}

/// The only thing the UI knows about video hosting. `R2HlsVideoSource` now,
/// `VdoCipherVideoSource` later (ADR-002).
abstract interface class VideoSource {
  Future<PlaybackInfo> getPlayback(String assetId);
}

/// SPIKE: talks to `spikes/video-hls/server`. The real client calls the `api`
/// Edge Function through `supabase.functions.invoke` with the user's JWT.
class SpikeHlsVideoSource implements VideoSource {
  SpikeHlsVideoSource({required this.serverUrl, required this.user});

  final Uri serverUrl;
  final String user;

  @override
  Future<PlaybackInfo> getPlayback(String assetId) async {
    final res = await http.post(
      serverUrl.resolve('/video-otp'),
      headers: {'content-type': 'application/json', 'x-spike-user': user},
      body: jsonEncode({'assetId': assetId}),
    );
    if (res.statusCode != 200) {
      throw VideoSourceException('video-otp ${res.statusCode}: ${res.body}');
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final watermark = json['watermark'] as Map<String, dynamic>;
    return PlaybackInfo(
      playlistUrl: Uri.parse(json['playlistUrl'] as String),
      expiresAt: DateTime.fromMillisecondsSinceEpoch(
        (json['expiresAt'] as int) * 1000,
      ),
      watermarkName: watermark['name'] as String,
      watermarkShortId: watermark['shortId'] as String,
    );
  }
}

class VideoSourceException implements Exception {
  VideoSourceException(this.message);
  final String message;
  @override
  String toString() => message;
}
