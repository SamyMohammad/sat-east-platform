import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/core/errors/supabase_error_mapper.dart';
import 'package:sat_east_client/core/supabase/edge_caller.dart';
import 'package:sat_east_client/core/supabase/rpc_caller.dart';
import 'package:sat_east_client/features/teacher/videos/domain/entities/video_upload.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Reads the `settings` rows `key,value` for the upload limits.
typedef VideoSettingsRows = Future<Object?> Function();

const _maxSourceKey = 'video_upload_max_source_mb';
const _maxDurationKey = 'video_upload_max_duration_s';

/// Server calls of the teacher video upload flow (`docs/07`).
class VideoUploadRemoteDataSource {
  VideoUploadRemoteDataSource({
    required this.rpc,
    required this.edge,
    required this.readSettings,
  });
  final RpcCaller rpc;
  final EdgeCaller edge;
  final VideoSettingsRows readSettings;

  /// Limits for the keys that exist; a missing key is a null limit.
  Future<Result<VideoUploadLimits>> limits() => _call(() async {
    final rows = await readSettings();
    if (rows is! List<Object?>) throw const FormatException('settings');
    final values = <String, int>{};
    for (final row in rows) {
      final json = _object(row);
      final key = json['key'];
      if (key is! String) throw const FormatException('key');
      if (key != _maxSourceKey && key != _maxDurationKey) continue;
      final value = json['value'];
      if (value is! int || value <= 0) throw const FormatException('value');
      values[key] = value;
    }
    return VideoUploadLimits(
      maxSourceMb: values[_maxSourceKey],
      maxDurationS: values[_maxDurationKey],
    );
  });

  Future<Result<String>> createAsset({
    required String topicId,
    required String? subtopicId,
    required String title,
    required int durationS,
    required int sizeMb,
  }) => _call(() async {
    final row = _object(
      await rpc('teacher_create_video_asset', {
        'p_topic_id': topicId,
        'p_subtopic_id': subtopicId,
        'p_title': title,
        'p_duration_s': durationS,
        'p_size_mb': sizeMb,
      }),
    );
    if (row['ok'] == false && row['error'] == ErrorCodes.quotaExceeded) {
      throw const _QuotaExceeded();
    }
    final id = row['asset_id'];
    if (row['ok'] != true || id is! String || id.isEmpty) {
      throw const FormatException('asset');
    }
    return id;
  });

  Future<Result<Map<String, String>>> uploadUrls(
    String assetId,
    List<String> files,
  ) => _call(() async {
    final reply = _object(
      await edge('teacher/video-upload-urls', {
        'asset_id': assetId,
        'files': files,
      }),
    );
    final raw = _object(reply['urls']);
    final urls = <String, String>{};
    for (final name in files) {
      final value = raw[name];
      if (value is! String || !_presigned(value)) {
        throw const FormatException('url');
      }
      urls[name] = value;
    }
    return Map.unmodifiable(urls);
  });

  Future<Result<void>> confirm(String assetId, String keyHex) =>
      _call(() async {
        final row = _object(
          await rpc('teacher_confirm_video_asset', {
            'p_asset_id': assetId,
            'p_key_hex': keyHex,
          }),
        );
        if (row['ok'] != true) throw const FormatException('ok');
      });

  Future<Result<T>> _call<T>(Future<T> Function() action) async {
    try {
      return Success(await action());
    } on _QuotaExceeded {
      return const Failure(AppError(ErrorCodes.quotaExceeded));
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

class _QuotaExceeded implements Exception {
  const _QuotaExceeded();
}

/// Same rule as `tools/video-pipeline/r2_upload.ts`: https, no userinfo.
bool _presigned(String value) {
  final uri = Uri.tryParse(value);
  return uri != null &&
      uri.scheme == 'https' &&
      uri.host.isNotEmpty &&
      uri.userInfo.isEmpty;
}

Map<String, Object?> _object(Object? raw) =>
    raw is Map<String, Object?> ? raw : throw const FormatException('object');
