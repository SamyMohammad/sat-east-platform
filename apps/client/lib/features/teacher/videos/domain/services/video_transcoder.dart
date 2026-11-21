import 'dart:typed_data';

import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/teacher/videos/domain/entities/picked_video.dart';
import 'package:sat_east_client/features/teacher/videos/domain/entities/video_upload.dart';

/// Packages a source video as AES-128 HLS (540p H.264 600k + 96k mono AAC,
/// 6 s segments), matching `tools/video-pipeline/ffmpeg.ts`. One instance is
/// used for one upload.
abstract interface class VideoTranscoder {
  /// False where the pipeline cannot run (everything except the web build).
  bool get isSupported;

  /// Transcode progress as a fraction in 0..1.
  Stream<double> get progress;

  /// Cheap duration read (no wasm load) used for the pre-check. Failure means
  /// the duration is unknown, not that the file is invalid.
  Future<Result<int>> probeDuration(PickedVideo source);

  /// Encrypts with the 16-byte [key]; the transcoder must not keep or mutate
  /// the caller's copy. Failure codes: `unsupported`, `cancelled`,
  /// `video_transcode_failed`.
  Future<Result<TranscodedVideo>> transcode(PickedVideo source, Uint8List key);

  /// Stops a running [transcode], which then completes with `cancelled`.
  Future<void> cancel();
}
