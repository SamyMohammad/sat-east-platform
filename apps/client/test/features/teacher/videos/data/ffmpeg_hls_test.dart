import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/features/teacher/videos/data/services/ffmpeg_hls.dart';

void main() {
  // Mirrors ffmpegArgs() in tools/video-pipeline/ffmpeg.ts with
  // input '/in/a.mp4', dir '/out', keyInfoPath '/key.info'.
  const audioArgs = ['-map', '0:a:0', '-c:a', 'aac', '-b:a', '96k', '-ac', '1'];
  const head = [
    '-y', '-hide_banner', '-loglevel', 'error', '-i', '/in/a.mp4', //
    '-map', '0:v:0', '-vf', 'scale=-2:540',
  ];
  const tail = [
    '-c:v', 'libx264', '-preset', 'veryfast', '-profile:v', 'main', //
    '-pix_fmt', 'yuv420p', '-b:v', '600k', '-maxrate:v', '650k',
    '-bufsize:v', '1300k',
    '-force_key_frames', 'expr:gte(t,n_forced*6)', '-sc_threshold', '0',
    '-f', 'hls', '-hls_time', '6', '-hls_playlist_type', 'vod',
    '-hls_key_info_file', '/key.info',
    '-hls_segment_filename', '/out/%v_%03d.ts',
    '-master_pl_name', 'master.m3u8',
    '-var_stream_map',
  ];

  test('VID-01: encode args match tools/video-pipeline/ffmpeg.ts', () {
    expect(ffmpegHlsArgs(input: '/in/a.mp4', audio: true), [
      ...head,
      ...audioArgs,
      ...tail,
      'v:0,a:0,name:540p',
      '/out/%v.m3u8',
    ]);
  });

  test('VID-01: a silent source drops the audio mapping like the CLI', () {
    expect(ffmpegHlsArgs(input: '/in/a.mp4', audio: false), [
      ...head,
      ...tail,
      'v:0,name:540p',
      '/out/%v.m3u8',
    ]);
  });

  test('VID-01: key info uses the key URI and the wasm key path', () {
    expect(ffmpegKeyInfo, 'key\n/key.bin\n');
  });

  group('parseFfmpegProbe', () {
    const log = [
      "Input #0, mov,mp4,m4a,3gp,3g2,mj2, from '/in/a.mp4':",
      '  Duration: 00:10:00.52, start: 0.000000, bitrate: 4003 kb/s',
      '  Stream #0:0[0x1](und): Video: h264 (High), yuv420p, 1920x1080',
      '  Stream #0:1[0x2](und): Audio: aac (LC), 44100 Hz, stereo',
    ];

    test('VID-01: duration rounds up and streams are detected', () {
      final probe = parseFfmpegProbe(log);
      expect(probe.durationS, 601);
      expect(probe.hasVideo, isTrue);
      expect(probe.hasAudio, isTrue);
    });

    test('VID-01: exact whole seconds are not bumped', () {
      expect(
        parseFfmpegProbe(['  Duration: 00:02:00.00, start: 0']).durationS,
        120,
      );
    });

    test('VID-01: video-only source with N/A duration', () {
      final probe = parseFfmpegProbe([
        '  Duration: N/A, bitrate: N/A',
        '  Stream #0:0: Video: vp9, yuv420p',
      ]);
      expect(probe.durationS, isNull);
      expect(probe.hasAudio, isFalse);
      expect(probe.hasVideo, isTrue);
    });

    test('VID-01: hours are included', () {
      expect(
        parseFfmpegProbe(['  Duration: 01:00:01.10, start: 0']).durationS,
        3602,
      );
    });
  });

  test('VID-01: playlist duration sums EXTINF and rounds up', () {
    const playlist =
        '#EXTM3U\n#EXT-X-KEY:METHOD=AES-128,URI="key"\n'
        '#EXTINF:6.000000,\n540p_000.ts\n#EXTINF:3.520000,\n540p_001.ts\n'
        '#EXT-X-ENDLIST\n';
    expect(hlsPlaylistDurationS(playlist), 10);
    expect(hlsPlaylistDurationS('#EXTM3U\n'), isNull);
  });
}
