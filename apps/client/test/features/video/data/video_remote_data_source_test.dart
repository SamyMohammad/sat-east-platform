import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/core/supabase/edge_caller.dart';
import 'package:sat_east_client/core/supabase/rpc_caller.dart';
import 'package:sat_east_client/features/video/data/datasources/video_remote_data_source.dart';
import 'package:sat_east_client/features/video/domain/entities/video_playback.dart';
import 'package:sat_east_client/features/video/domain/entities/video_settings.dart';
import 'package:sat_east_client/features/video/domain/entities/watched_span.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  VideoRemoteDataSource source({
    EdgeCaller? edge,
    RpcCaller? rpc,
    VideoSettingsReader? settings,
  }) => VideoRemoteDataSource(
    edge: edge ?? (_, _) async => null,
    rpc: rpc ?? (_, _) async => null,
    readSettings:
        settings ??
        () async => [
          {'key': 'video_progress_interval_s', 'value': 15},
          {'key': 'video_watermark_move_s', 'value': 7},
        ],
  );

  test('SEC-01: requests R2 playback and parses epoch expiration', () async {
    final remote = source(
      edge: (path, body) async {
        expect(path, 'video-otp');
        expect(body, {'asset_id': 'v'});
        return {
          'provider': 'r2_hls',
          'hls_url': 'https://example.test/master.m3u8',
          'expires_at': 1800000000,
          'watermark': {'name': 'Sara Ali', 'short_id': '3FA2C1'},
          'resume_s': 120,
        };
      },
    );
    final playback =
        (await remote.requestPlayback('v') as Success<VideoPlayback>).value
            as HlsPlayback;
    expect(playback.hlsUrl, 'https://example.test/master.m3u8');
    expect(
      playback.expiresAt,
      DateTime.fromMillisecondsSinceEpoch(1800000000000, isUtc: true),
    );
    expect(playback.watermarkText, 'Sara Ali \u00b7 3FA2C1');
    expect(playback.resumeS, 120);
  });
  test('LRN-02: parses YouTube playback', () async {
    final remote = source(
      edge: (_, _) async => {
        'provider': 'youtube',
        'youtube_id': 'dQw4w9WgXcQ',
        'resume_s': 12,
      },
    );
    final playback =
        (await remote.requestPlayback('v') as Success<VideoPlayback>).value
            as YoutubePlayback;
    expect(playback.youtubeId, 'dQw4w9WgXcQ');
    expect(playback.resumeS, 12);
  });
  test(
    'SEC-01: null watermark name accepted by the server becomes empty text',
    () async {
      final result = await source(
        edge: (_, _) async => {
          'provider': 'r2_hls',
          'hls_url': 'https://example.test/master.m3u8',
          'expires_at': 1800000000,
          'watermark': {'name': null, 'short_id': '3FA2C1'},
          'resume_s': 0,
        },
      ).requestPlayback('v');
      expect(
        ((result as Success<VideoPlayback>).value as HlsPlayback).watermarkName,
        '',
      );
    },
  );
  test('LRN-02: maps FunctionException video_needed', () async {
    final result = await source(
      edge: (_, _) async => throw const FunctionException(
        status: 400,
        details: {
          'error': {'code': 'video_needed'},
        },
      ),
    ).requestPlayback('v');
    expect((result as Failure<VideoPlayback>).error.code, 'video_needed');
  });
  test(
    'LRN-02: sends watched span and position without client percentage',
    () async {
      final remote = source(
        rpc: (fn, params) async {
          expect(fn, 'save_video_progress');
          expect(params, {
            'p_asset_id': 'v',
            'p_from_s': 0,
            'p_to_s': 14,
            'p_position_s': 14,
          });
          return {'pct': 80, 'done': true};
        },
      );
      final result = await remote.saveProgress(
        'v',
        const WatchedSpan(fromS: 0, toS: 14),
        14,
      );
      expect((result as Success<({int pct, bool done})>).value, (
        pct: 80,
        done: true,
      ));
    },
  );
  test('SEC-01: maps forbidden save error', () async {
    final result = await source(
      rpc: (_, _) async => throw const PostgrestException(message: 'forbidden'),
    ).saveProgress('v', const WatchedSpan(fromS: 0, toS: 14), 14);
    expect((result as Failure<({int pct, bool done})>).error.code, 'forbidden');
  });
  test('LRN-02: reads both video settings', () async {
    final result = await source().loadSettings();
    final settings = (result as Success<VideoSettings>).value;
    expect(settings.progressIntervalS, 15);
    expect(settings.watermarkMoveS, 7);
  });
  for (final rows in <Object?>[
    [],
    [
      {'key': 'video_progress_interval_s', 'value': 15},
    ],
    [
      {'key': 'video_progress_interval_s', 'value': 0},
      {'key': 'video_watermark_move_s', 'value': 7},
    ],
    [
      {'key': 'video_progress_interval_s', 'value': '15'},
      {'key': 'video_watermark_move_s', 'value': 7},
    ],
  ]) {
    test(
      'LRN-02: missing or malformed settings fail internally $rows',
      () async {
        final result = await source(settings: () async => rows).loadSettings();
        expect((result as Failure<VideoSettings>).error.code, 'internal');
      },
    );
  }
  for (final response in <Object?>[
    null,
    {},
    {'provider': 'unknown', 'resume_s': 0},
    {'provider': 'youtube', 'resume_s': -1, 'youtube_id': 'dQw4w9WgXcQ'},
    {'provider': 'youtube', 'resume_s': 0, 'youtube_id': 'bad'},
  ]) {
    test('SEC-01: malformed playback fails internally $response', () async {
      final result = await source(
        edge: (_, _) async => response,
      ).requestPlayback('v');
      expect((result as Failure<VideoPlayback>).error.code, 'internal');
    });
  }
  test('LRN-02: transport timeout maps to network', () async {
    final result = await source(
      edge: (_, _) async => throw TimeoutException('offline'),
    ).requestPlayback('v');
    expect((result as Failure<VideoPlayback>).error.code, 'network');
  });
  test('LRN-02: malformed progress fails internally', () async {
    final result = await source(
      rpc: (_, _) async => {'pct': 101, 'done': true},
    ).saveProgress('v', const WatchedSpan(fromS: 0, toS: 14), 14);
    expect((result as Failure<({int pct, bool done})>).error.code, 'internal');
  });
}
