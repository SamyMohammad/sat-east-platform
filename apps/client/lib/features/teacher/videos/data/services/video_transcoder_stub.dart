import 'dart:typed_data';

import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/teacher/videos/domain/entities/picked_video.dart';
import 'package:sat_east_client/features/teacher/videos/domain/entities/video_upload.dart';
import 'package:sat_east_client/features/teacher/videos/domain/services/video_transcoder.dart';

VideoTranscoder createVideoTranscoder() => const UnsupportedVideoTranscoder();

/// Non-web builds cannot run ffmpeg.wasm: teachers upload from the web app.
class UnsupportedVideoTranscoder implements VideoTranscoder {
  const UnsupportedVideoTranscoder();

  static const _unsupported = AppError(ErrorCodes.unsupported);

  @override
  bool get isSupported => false;

  @override
  Stream<double> get progress => const Stream<double>.empty();

  @override
  Future<Result<int>> probeDuration(PickedVideo source) async =>
      const Failure(_unsupported);

  @override
  Future<Result<TranscodedVideo>> transcode(
    PickedVideo source,
    Uint8List key,
  ) async => const Failure(_unsupported);

  @override
  Future<void> cancel() async {}
}
