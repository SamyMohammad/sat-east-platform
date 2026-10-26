import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sat_east_client/core/theme/booklet_tokens.dart';
import 'package:sat_east_client/features/video/domain/services/video_engine.dart';
import 'package:sat_east_client/features/video/presentation/video_copy.dart';

class VideoControls extends StatelessWidget {
  const VideoControls({
    required this.status,
    required this.positionS,
    required this.durationS,
    required this.rate,
    required this.fullscreen,
    required this.onTogglePlay,
    required this.onSeek,
    required this.onSetRate,
    required this.onToggleFullscreen,
    super.key,
  });

  final EngineStatus status;
  final double positionS;
  final double? durationS;
  final double rate;
  final bool fullscreen;
  final VoidCallback onTogglePlay;
  final ValueChanged<double> onSeek;
  final ValueChanged<double> onSetRate;
  final VoidCallback onToggleFullscreen;

  @override
  Widget build(BuildContext context) {
    final playing =
        status == EngineStatus.playing || status == EngineStatus.buffering;
    final duration = durationS;
    final seekable = duration != null && duration.isFinite && duration > 0;
    final max = seekable ? duration : 1.0;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.space): onTogglePlay,
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
            onSeek(positionS - 10),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
            onSeek(positionS + 10),
      },
      child: Focus(
        autofocus: true,
        child: Material(
          color: Theme.of(context).colorScheme.surfaceContainer,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: BookletSpace.s2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  label: VideoCopy.seek,
                  child: Slider(
                    value: positionS.clamp(0.0, max),
                    max: max,
                    onChanged: seekable ? onSeek : null,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      tooltip: playing ? VideoCopy.pause : VideoCopy.play,
                      onPressed: onTogglePlay,
                      icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                    ),
                    Expanded(
                      child: Text(
                        '${VideoCopy.time(positionS)} / '
                        '${VideoCopy.time(duration ?? 0)}',
                        maxLines: 1,
                      ),
                    ),
                    PopupMenuButton<double>(
                      tooltip: VideoCopy.speed,
                      initialValue: rate,
                      onSelected: onSetRate,
                      itemBuilder: (_) => [
                        for (final entry in VideoCopy.speeds)
                          PopupMenuItem(
                            value: entry.$1,
                            child: Text(entry.$2),
                          ),
                      ],
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          minWidth: BookletSize.touchTarget,
                          minHeight: BookletSize.touchTarget,
                        ),
                        child: Center(child: Text(VideoCopy.speedLabel(rate))),
                      ),
                    ),
                    IconButton(
                      onPressed: onToggleFullscreen,
                      tooltip: fullscreen
                          ? VideoCopy.exitFullscreen
                          : VideoCopy.fullscreen,
                      icon: Icon(
                        fullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
