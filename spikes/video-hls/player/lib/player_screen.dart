import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hls_spike/moving_watermark.dart';
import 'package:hls_spike/video_source.dart';
import 'package:video_player/video_player.dart';

/// SPIKE screen: plain StatefulWidget on purpose. SEC-01 turns this into a
/// Cubit + VideoRepository per ADR-007.
class PlayerScreen extends StatefulWidget {
  const PlayerScreen({
    required this.source,
    required this.assetId,
    required this.autoplay,
    super.key,
  });

  final VideoSource source;
  final String assetId;
  final bool autoplay;

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  VideoPlayerController? _controller;
  PlaybackInfo? _info;
  String _status = 'Starting…';
  Duration _lastPosition = Duration.zero;
  bool _recovering = false;
  int _recoveries = 0;
  final List<String> _log = [];

  /// Stall watchdog. On web, video_player_web_hls 1.3.0 swallows fatal
  /// hls.js errors (its error parser throws in release builds), so a dead
  /// stream only shows up as "playing, but the position does not move".
  static const _stallLimit = Duration(seconds: 10);
  late final Timer _watchdog;
  Duration _watchPosition = Duration.zero;
  Duration _stalledFor = Duration.zero;

  @override
  void initState() {
    super.initState();
    _watchdog = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _checkStall(),
    );
    unawaited(_open(resumeAt: Duration.zero));
  }

  void _checkStall() {
    final v = _controller?.value;
    if (v == null || !v.isInitialized || !v.isPlaying || _recovering) {
      _stalledFor = Duration.zero;
      return;
    }
    if (v.position != _watchPosition) {
      _watchPosition = v.position;
      _stalledFor = Duration.zero;
      return;
    }
    _stalledFor += const Duration(seconds: 1);
    if (_stalledFor >= _stallLimit) {
      _stalledFor = Duration.zero;
      _onPlayerError('stalled ${_stallLimit.inSeconds}s at ${v.position}');
    }
  }

  void _addLog(String line) {
    final t = DateTime.now().toIso8601String().substring(11, 19);
    // ignore: avoid_print — spike diagnostics, read from the browser console.
    print('[hls-spike] $line');
    if (mounted) setState(() => _log.insert(0, '$t $line'));
  }

  Future<void> _open({required Duration resumeAt}) async {
    try {
      final info = await widget.source.getPlayback(widget.assetId);
      _addLog('video-otp ok, token expires ${info.expiresAt.toLocal()}');
      final controller = VideoPlayerController.networkUrl(
        info.playlistUrl,
        formatHint: VideoFormat.hls,
        videoPlayerOptions: VideoPlayerOptions(
          webOptions: const VideoPlayerWebOptions(
            allowContextMenu: false, // no "Save video as…" / PiP menu
            allowRemotePlayback: false,
          ),
        ),
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      controller.addListener(_onTick);
      final old = _controller;
      setState(() {
        _info = info;
        _controller = controller;
        _status =
            'Ready (${controller.value.size.width.toInt()}x'
            '${controller.value.size.height.toInt()})';
      });
      await old?.dispose();
      if (resumeAt > Duration.zero) await controller.seekTo(resumeAt);
      if (widget.autoplay || resumeAt > Duration.zero) {
        if (widget.autoplay) await controller.setVolume(0);
        await controller.play();
      }
    } on Object catch (e) {
      _addLog('open failed: $e');
      if (mounted) setState(() => _status = 'Could not load the video.');
    }
  }

  void _onTick() {
    final c = _controller;
    if (c == null) return;
    final v = c.value;
    if (v.hasError) {
      _onPlayerError(v.errorDescription ?? 'unknown');
      return;
    }
    if (v.position > Duration.zero) _lastPosition = v.position;
    if (mounted) setState(() {});
  }

  /// Expired token (rendition switch, long pause) or network blip: ask for a
  /// fresh token once and resume where the student was.
  void _onPlayerError(String description) {
    if (_recovering) return;
    _controller?.removeListener(_onTick);
    _addLog('player error: $description');
    if (_recoveries >= 1) {
      setState(() => _status = 'Playback failed. Tap retry.');
      return;
    }
    _recovering = true;
    _recoveries++;
    _addLog('recovering at ${_lastPosition.inSeconds}s');
    unawaited(
      _open(resumeAt: _lastPosition).whenComplete(() => _recovering = false),
    );
  }

  @override
  void dispose() {
    _watchdog.cancel();
    _controller?.removeListener(_onTick);
    unawaited(_controller?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    final info = _info;
    return Scaffold(
      appBar: AppBar(title: const Text('Encrypted HLS spike')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: ColoredBox(
              color: Colors.black,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (c != null && c.value.isInitialized)
                    Center(
                      child: AspectRatio(
                        aspectRatio: c.value.aspectRatio,
                        child: VideoPlayer(c),
                      ),
                    ),
                  if (info != null)
                    MovingWatermark(
                      text: '${info.watermarkName} · ${info.watermarkShortId}',
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (c != null && c.value.isInitialized) _Controls(controller: c),
          const SizedBox(height: 8),
          Text(_status),
          if (_status.startsWith('Playback failed'))
            TextButton(
              onPressed: () {
                _recoveries = 0;
                unawaited(_open(resumeAt: _lastPosition));
              },
              child: const Text('Retry'),
            ),
          const Divider(),
          for (final line in _log.take(20))
            Text(line, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({required this.controller});

  final VideoPlayerController controller;

  @override
  Widget build(BuildContext context) {
    final v = controller.value;
    return Row(
      children: [
        IconButton(
          icon: Icon(v.isPlaying ? Icons.pause : Icons.play_arrow),
          onPressed: () =>
              unawaited(v.isPlaying ? controller.pause() : controller.play()),
        ),
        Expanded(
          child: VideoProgressIndicator(controller, allowScrubbing: true),
        ),
        const SizedBox(width: 8),
        Text('${v.position.inSeconds}s / ${v.duration.inSeconds}s'),
      ],
    );
  }
}
