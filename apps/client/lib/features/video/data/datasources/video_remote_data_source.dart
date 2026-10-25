import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/core/errors/supabase_error_mapper.dart';
import 'package:sat_east_client/core/supabase/edge_caller.dart';
import 'package:sat_east_client/core/supabase/rpc_caller.dart';
import 'package:sat_east_client/core/video/video_provider.dart';
import 'package:sat_east_client/features/video/domain/entities/video_playback.dart';
import 'package:sat_east_client/features/video/domain/entities/video_settings.dart';
import 'package:sat_east_client/features/video/domain/entities/watched_span.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef VideoSettingsReader = Future<Object?> Function();

class VideoRemoteDataSource {
  VideoRemoteDataSource({
    required this._edge,
    required this._rpc,
    required this._readSettings,
  });

  final EdgeCaller _edge;
  final RpcCaller _rpc;
  final VideoSettingsReader _readSettings;

  Future<Result<VideoPlayback>> requestPlayback(String assetId) =>
      _call(() async {
        final json = _map(await _edge('video-otp', {'asset_id': assetId}));
        final resume = _integer(json['resume_s']);
        return switch (VideoProvider.fromWire(_string(json['provider']))) {
          VideoProvider.r2Hls => _hls(json, resume),
          VideoProvider.youtube => _youtube(json, resume),
        };
      });

  Future<Result<({int pct, bool done})>> saveProgress(
    String assetId,
    WatchedSpan span,
    int positionS,
  ) => _call(() async {
    final json = _map(
      await _rpc('save_video_progress', {
        'p_asset_id': assetId,
        'p_from_s': span.fromS,
        'p_to_s': span.toS,
        'p_position_s': positionS,
      }),
    );
    final pct = _integer(json['pct']);
    final done = json['done'];
    if (pct > 100 || done is! bool) throw const FormatException('progress');
    return (pct: pct, done: done);
  });

  Future<Result<VideoSettings>> loadSettings() => _call(() async {
    final rows = await _readSettings();
    if (rows is! List<Object?>) throw const FormatException('settings');
    final values = <String, int>{};
    for (final row in rows) {
      final json = _map(row);
      final key = _string(json['key']);
      final value = _integer(json['value']);
      if (value == 0 || values.containsKey(key)) {
        throw const FormatException('setting');
      }
      values[key] = value;
    }
    final interval = values['video_progress_interval_s'];
    final move = values['video_watermark_move_s'];
    if (interval == null || move == null) {
      throw const FormatException('missing setting');
    }
    return VideoSettings(progressIntervalS: interval, watermarkMoveS: move);
  });

  HlsPlayback _hls(Map<String, Object?> json, int resume) {
    final url = _string(json['hls_url']);
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !uri.hasAuthority ||
        (uri.scheme != 'https' && uri.scheme != 'http')) {
      throw const FormatException('hls_url');
    }
    final watermark = _map(json['watermark']);
    final name = watermark['name'];
    if (!watermark.containsKey('name') || (name != null && name is! String)) {
      throw const FormatException('watermark');
    }
    return HlsPlayback(
      hlsUrl: url,
      expiresAt: DateTime.fromMillisecondsSinceEpoch(
        _integer(json['expires_at']) * 1000,
        isUtc: true,
      ),
      watermarkName: name as String? ?? '',
      watermarkShortId: _string(watermark['short_id']),
      resumeS: resume,
    );
  }

  YoutubePlayback _youtube(Map<String, Object?> json, int resume) {
    final id = _string(json['youtube_id']);
    if (!RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(id)) {
      throw const FormatException('youtube_id');
    }
    return YoutubePlayback(youtubeId: id, resumeS: resume);
  }

  Future<Result<T>> _call<T>(Future<T> Function() action) async {
    try {
      return Success(await action());
    } on FunctionException catch (e) {
      return Failure(mapFunctionException(e));
    } on PostgrestException catch (e) {
      return Failure(mapPostgrestException(e));
    } on AuthException catch (e) {
      return Failure(mapAuthException(e));
    } on FormatException {
      return const Failure(AppError(ErrorCodes.internal));
    } on Object catch (e) {
      // Parsing and transport errors can contain signed playback URLs.
      return Failure(AppError(mapUnknownError(e).code));
    }
  }
}

Map<String, Object?> _map(Object? value) => value is Map<String, Object?>
    ? value
    : throw const FormatException('object');

String _string(Object? value) => value is String && value.trim().isNotEmpty
    ? value
    : throw const FormatException('string');

int _integer(Object? value) =>
    value is int && value >= 0 ? value : throw const FormatException('integer');
