import 'package:flutter/material.dart';
import 'package:hls_spike/player_screen.dart';
import 'package:hls_spike/video_source.dart';

/// SPIKE app (ADR-002). Config from --dart-define, overridable on web with
/// query parameters: ?server=http://host:8787&asset=demo1&user=Sara&autoplay=1
/// (autoplay starts muted, so browsers allow it without a tap).
void main() {
  const defaultServer = String.fromEnvironment(
    'SERVER_URL',
    defaultValue: 'http://localhost:8787',
  );
  const defaultAsset = String.fromEnvironment(
    'ASSET_ID',
    defaultValue: 'demo1',
  );
  final q = Uri.base.queryParameters;
  runApp(
    SpikeApp(
      source: SpikeHlsVideoSource(
        serverUrl: Uri.parse(q['server'] ?? defaultServer),
        user: q['user'] ?? 'Sara Ahmed',
      ),
      assetId: q['asset'] ?? defaultAsset,
      autoplay: q['autoplay'] == '1',
    ),
  );
}

class SpikeApp extends StatelessWidget {
  const SpikeApp({
    required this.source,
    required this.assetId,
    required this.autoplay,
    super.key,
  });

  final VideoSource source;
  final String assetId;
  final bool autoplay;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HLS spike',
      theme: ThemeData.dark(useMaterial3: true),
      home: PlayerScreen(source: source, assetId: assetId, autoplay: autoplay),
    );
  }
}
