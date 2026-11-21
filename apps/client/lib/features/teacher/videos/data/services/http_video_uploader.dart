import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/core/errors/supabase_error_mapper.dart';
import 'package:sat_east_client/features/teacher/videos/domain/entities/video_upload.dart';
import 'package:sat_east_client/features/teacher/videos/domain/services/video_uploader.dart';

const _parallelPuts = 4;

/// Port of `tools/video-pipeline/r2_upload.ts`: presigned PUTs, four at a
/// time, redirects refused, first failure stops new requests and only the
/// status code is reported (never URLs or response bodies).
class HttpVideoUploader implements VideoUploader {
  HttpVideoUploader(this._client);
  final http.Client _client;
  bool _cancelled = false;

  @override
  void cancel() => _cancelled = true;

  @override
  Future<Result<void>> upload(
    List<HlsFile> files,
    Map<String, String> urls, {
    void Function(int done, int total)? onProgress,
  }) async {
    var next = 0;
    var done = 0;
    AppError? failure;
    Future<void> worker() async {
      while (failure == null && !_cancelled && next < files.length) {
        final file = files[next++];
        final error = await _put(file, urls[file.name]);
        if (error != null) {
          failure ??= error;
        } else {
          onProgress?.call(++done, files.length);
        }
      }
    }

    // Every in-flight PUT is drained before returning, so a rollback cannot
    // race an object that is still being written.
    await Future.wait([
      for (var i = 0; i < _parallelPuts && i < files.length; i++) worker(),
    ]);
    final error = failure;
    if (error != null) return Failure(error);
    if (_cancelled) return const Failure(AppError(ErrorCodes.cancelled));
    return const Success(null);
  }

  Future<AppError?> _put(HlsFile file, String? url) async {
    final uri = url == null ? null : Uri.tryParse(url);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      return const AppError(ErrorCodes.videoUploadFailed);
    }
    try {
      final request = http.Request('PUT', uri)
        ..followRedirects = false
        ..headers['content-type'] = file.contentType
        ..bodyBytes = file.bytes;
      final response = await _client.send(request);
      await response.stream.drain<void>();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return AppError(
          ErrorCodes.videoUploadFailed,
          'HTTP ${response.statusCode}',
        );
      }
      return null;
    } on Object catch (e) {
      // mapUnknownError keeps the raw text for logs only; drop it here since
      // it can contain the presigned URL.
      final code = mapUnknownError(e).code;
      return AppError(
        code == ErrorCodes.network ? code : ErrorCodes.videoUploadFailed,
      );
    }
  }
}
