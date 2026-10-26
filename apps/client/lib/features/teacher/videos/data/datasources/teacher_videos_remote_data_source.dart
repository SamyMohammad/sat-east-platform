import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/core/errors/supabase_error_mapper.dart';
import 'package:sat_east_client/core/supabase/edge_caller.dart';
import 'package:sat_east_client/core/supabase/rpc_caller.dart';
import 'package:sat_east_client/core/video/video_provider.dart';
import 'package:sat_east_client/features/teacher/videos/domain/entities/teacher_video.dart';
import 'package:sat_east_client/features/teacher/videos/domain/entities/video_quota.dart';
import 'package:sat_east_client/features/teacher/videos/domain/youtube_id.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TeacherVideosRemoteDataSource {
  TeacherVideosRemoteDataSource({required this.rpc, required this.edge});
  final RpcCaller rpc;
  final EdgeCaller edge;

  Future<Result<List<TeacherVideo>>> list(String topicId) => _call(() async {
    final raw = await rpc('teacher_list_videos', {'p_topic_id': topicId});
    if (raw is! List<Object?>) throw const FormatException('videos');
    return List.unmodifiable(raw.map(_video));
  });

  Future<Result<VideoQuota>> quota() => _call(() async {
    final row = _object(await rpc('teacher_video_quota', {}));
    final cap = _integer(row['cap_mb']);
    if (cap == 0) throw const FormatException('storage cap');
    return VideoQuota(usedMb: _integer(row['used_mb']), capMb: cap);
  });

  Future<Result<void>> addYoutube(
    String topicId,
    String title,
    String youtubeId,
    int durationS,
  ) => _write('teacher_add_youtube_video', {
    'p_topic_id': topicId,
    'p_subtopic_id': null,
    'p_title': title,
    'p_youtube_id': youtubeId,
    'p_duration_s': durationS,
  });

  Future<Result<void>> update(
    String assetId,
    String title,
    String? subtopicId,
  ) => _write('teacher_update_video', {
    'p_asset_id': assetId,
    'p_title': title,
    'p_subtopic_id': subtopicId,
  });

  Future<Result<void>> reorder(String topicId, List<String> ids) =>
      _write('teacher_reorder_videos', {'p_topic_id': topicId, 'p_ids': ids});

  Future<Result<void>> delete(String assetId) => _call(() async {
    _ack(await edge('teacher/video-delete', {'asset_id': assetId}));
  });

  Future<Result<void>> _write(String name, Map<String, Object?> params) =>
      _call(() async {
        _ack(await rpc(name, params));
      });

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
      return Failure(AppError(mapUnknownError(e).code));
    }
  }
}

TeacherVideo _video(Object? raw) {
  final row = _object(raw);
  final duration = _integer(row['duration_s']);
  final ready = row['ready'];
  if (duration == 0 || ready is! bool) throw const FormatException('video');
  final provider = VideoProvider.fromWire(_text(row['provider']));
  final youtubeId = _optionalText(row['youtube_id']);
  if (provider == VideoProvider.youtube &&
      (youtubeId == null || parseYoutubeId(youtubeId) != youtubeId)) {
    throw const FormatException('youtube id');
  }
  return TeacherVideo(
    assetId: _text(row['asset_id']),
    title: _text(row['title']),
    durationS: duration,
    provider: provider,
    ready: ready,
    sort: _integer(row['sort']),
    subtopicId: _optionalText(row['subtopic_id']),
    subtopicTitle: _optionalText(row['subtopic_title']),
    sizeMb: row['size_mb'] == null ? null : _integer(row['size_mb']),
    youtubeId: youtubeId,
  );
}

void _ack(Object? raw) {
  if (_object(raw)['ok'] != true) throw const FormatException('ok');
}

Map<String, Object?> _object(Object? raw) =>
    raw is Map<String, Object?> ? raw : throw const FormatException('object');
String _text(Object? raw) => raw is String && raw.trim().isNotEmpty
    ? raw
    : throw const FormatException('text');
String? _optionalText(Object? raw) => raw == null ? null : _text(raw);
int _integer(Object? raw) =>
    raw is int && raw >= 0 ? raw : throw const FormatException('integer');
