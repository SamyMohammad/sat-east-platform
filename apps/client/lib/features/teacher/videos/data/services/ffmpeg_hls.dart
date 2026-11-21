/// Pure helpers for the browser ffmpeg pipeline (no JS), kept separate so
/// they are unit-testable on the VM.
library;

/// wasm-FS paths used by the web transcoder.
const ffmpegOutDir = '/out';
const ffmpegKeyPath = '/key.bin';
const ffmpegKeyInfoPath = '/key.info';

/// `key.info` for `-hls_key_info_file`: key URI `key`, key file path. No IV,
/// so HLS uses the segment sequence number (as the CLI).
const ffmpegKeyInfo = 'key\n$ffmpegKeyPath\n';

/// Same arguments as `ffmpegArgs` in `tools/video-pipeline/ffmpeg.ts`, with
/// the wasm FS paths substituted.
List<String> ffmpegHlsArgs({required String input, required bool audio}) => [
  '-y',
  '-hide_banner',
  '-loglevel',
  'error',
  '-i',
  input,
  '-map',
  '0:v:0',
  '-vf',
  'scale=-2:540',
  if (audio) ...['-map', '0:a:0', '-c:a', 'aac', '-b:a', '96k', '-ac', '1'],
  '-c:v',
  'libx264',
  '-preset',
  'veryfast',
  '-profile:v',
  'main',
  '-pix_fmt',
  'yuv420p',
  '-b:v',
  '600k',
  '-maxrate:v',
  '650k',
  '-bufsize:v',
  '1300k',
  '-force_key_frames',
  'expr:gte(t,n_forced*6)',
  '-sc_threshold',
  '0',
  '-f',
  'hls',
  '-hls_time',
  '6',
  '-hls_playlist_type',
  'vod',
  '-hls_key_info_file',
  ffmpegKeyInfoPath,
  '-hls_segment_filename',
  '$ffmpegOutDir/%v_%03d.ts',
  '-master_pl_name',
  'master.m3u8',
  '-var_stream_map',
  if (audio) 'v:0,a:0,name:540p' else 'v:0,name:540p',
  '$ffmpegOutDir/%v.m3u8',
];

/// Arguments for the probe run (`ffmpeg -i`, no output): it exits non-zero
/// by design but logs the container duration and the streams.
List<String> ffmpegProbeArgs(String input) => ['-hide_banner', '-i', input];

class FfmpegProbe {
  const FfmpegProbe({
    required this.durationS,
    required this.hasVideo,
    required this.hasAudio,
  });

  /// Container duration rounded up, null when ffmpeg printed `N/A`.
  final int? durationS;
  final bool hasVideo;
  final bool hasAudio;
}

final _duration = RegExp(r'Duration:\s*(\d+):(\d{2}):(\d{2}(?:\.\d+)?)');
final _video = RegExp(r'Stream #\d+:\d+.*?: Video:');
final _audio = RegExp(r'Stream #\d+:\d+.*?: Audio:');

/// Parses the log lines of [ffmpegProbeArgs], the ffprobe equivalent for
/// duration (`format=duration`, rounded up) and the `a:0` check.
FfmpegProbe parseFfmpegProbe(Iterable<String> logLines) {
  int? durationS;
  var hasVideo = false;
  var hasAudio = false;
  for (final line in logLines) {
    final duration = _duration.firstMatch(line);
    if (duration != null && durationS == null) {
      final seconds =
          int.parse(duration[1]!) * 3600 +
          int.parse(duration[2]!) * 60 +
          double.parse(duration[3]!);
      durationS = seconds.ceil();
    }
    hasVideo = hasVideo || _video.hasMatch(line);
    hasAudio = hasAudio || _audio.hasMatch(line);
  }
  return FfmpegProbe(
    durationS: durationS != null && durationS > 0 ? durationS : null,
    hasVideo: hasVideo,
    hasAudio: hasAudio,
  );
}

final _extinf = RegExp(r'^#EXTINF:(\d+(?:\.\d+)?)', multiLine: true);

/// Sum of `#EXTINF` durations, rounded up; fallback when the probe log has no
/// duration. Null for an empty playlist.
int? hlsPlaylistDurationS(String playlist) {
  var total = 0.0;
  for (final match in _extinf.allMatches(playlist)) {
    total += double.parse(match[1]!);
  }
  return total > 0 ? total.ceil() : null;
}
