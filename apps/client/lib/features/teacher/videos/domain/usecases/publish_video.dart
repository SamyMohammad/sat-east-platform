import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/teacher/videos/domain/entities/teacher_video.dart';
import 'package:sat_east_client/features/teacher/videos/domain/entities/video_quota.dart';
import 'package:sat_east_client/features/teacher/videos/domain/entities/video_upload.dart';
import 'package:sat_east_client/features/teacher/videos/domain/repositories/teacher_videos_repository.dart';
import 'package:sat_east_client/features/teacher/videos/domain/repositories/video_upload_repository.dart';
import 'package:sat_east_client/features/teacher/videos/domain/services/video_transcoder.dart';
import 'package:sat_east_client/features/teacher/videos/domain/services/video_uploader.dart';
import 'package:sat_east_client/features/teacher/videos/domain/video_duration.dart';

const _bytesPerMb = 1048576;
const _maxFiles = 2000;
const _keyLength = 16;
const _cleanupAttempts = 3;
const _cleanupBackoff = Duration(milliseconds: 500);

/// Whole MB, rounded up (`sizeMb` in `tools/video-pipeline/publish.ts`).
int videoSizeMb(Iterable<int> byteLengths) {
  final total = byteLengths.fold<int>(0, (sum, value) => sum + value);
  return (total + _bytesPerMb - 1) ~/ _bytesPerMb;
}

String videoKeyHex(Uint8List key) =>
    key.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();

Uint8List _secureKey() {
  final random = Random.secure();
  return Uint8List.fromList(
    List<int>.generate(_keyLength, (_) => random.nextInt(256)),
  );
}

/// Browser port of `publish.ts`: pre-checks, transcode, reserve, PUT, confirm,
/// and rollback of the reservation on any later failure. One instance per
/// upload (it holds the cancel flag).
class PublishVideo {
  PublishVideo({
    required this._videos,
    required this._uploads,
    required this._transcoder,
    required this._uploader,
    Uint8List Function()? randomKey,
    Future<void> Function(Duration)? delay,
  }) : _randomKey = randomKey ?? _secureKey,
       _delay = delay ?? Future<void>.delayed;

  final TeacherVideosRepository _videos;
  final VideoUploadRepository _uploads;
  final VideoTranscoder _transcoder;
  final VideoUploader _uploader;
  final Uint8List Function() _randomKey;
  final Future<void> Function(Duration) _delay;
  bool _cancelled = false;

  static const _cancelledFailure = Failure<PublishedVideo>(
    AppError(ErrorCodes.cancelled),
  );

  /// Stops the upload. Before a reservation nothing is left behind; after it
  /// the reservation is deleted and [call] completes with `cancelled`.
  Future<void> cancel() async {
    _cancelled = true;
    _uploader.cancel();
    await _transcoder.cancel();
  }

  Future<Result<PublishedVideo>> call(
    PublishVideoRequest request, {
    void Function(PublishProgress progress)? onProgress,
  }) async {
    if (!_transcoder.isSupported) {
      return const Failure(AppError(ErrorCodes.unsupported));
    }
    if (!TeacherVideo.validTitle(request.title)) {
      return const Failure(AppError(ErrorCodes.invalidInput));
    }
    final key = _randomKey();
    if (key.length != _keyLength) {
      return const Failure(AppError(ErrorCodes.internal));
    }
    try {
      return await _run(request, key, onProgress ?? (_) {});
    } finally {
      key.fillRange(0, key.length, 0);
    }
  }

  Future<Result<PublishedVideo>> _run(
    PublishVideoRequest request,
    Uint8List key,
    void Function(PublishProgress) report,
  ) async {
    report(const PublishChecking());
    final limitsResult = await _uploads.limits();
    if (limitsResult is Failure<VideoUploadLimits>) {
      return Failure(limitsResult.error);
    }
    final limits = (limitsResult as Success<VideoUploadLimits>).value;
    final maxSourceMb = limits.maxSourceMb;
    if (maxSourceMb != null &&
        request.source.sizeBytes > maxSourceMb * _bytesPerMb) {
      return const Failure(AppError(ErrorCodes.videoTooLarge));
    }
    // A failed probe only means "unknown": the transcoded duration is checked
    // again below, before anything is reserved.
    final probe = await _transcoder.probeDuration(request.source);
    final maxDurationS = limits.maxDurationS;
    if (probe is Success<int> &&
        maxDurationS != null &&
        probe.value > maxDurationS) {
      return const Failure(AppError(ErrorCodes.videoTooLong));
    }
    if (_cancelled) return _cancelledFailure;

    final early = await _videos.quota();
    if (early is Failure<VideoQuota>) return Failure(early.error);
    final earlyQuota = (early as Success<VideoQuota>).value;
    if (earlyQuota.usedMb >= earlyQuota.capMb) {
      return const Failure(AppError(ErrorCodes.quotaExceeded));
    }
    if (_cancelled) return _cancelledFailure;

    report(const PublishTranscoding(0));
    final subscription = _transcoder.progress.listen(
      (value) => report(PublishTranscoding(value.clamp(0.0, 1.0))),
    );
    final Result<TranscodedVideo> transcoded;
    // The transcoder may detach the buffer it is given; keep the original.
    final keyCopy = Uint8List.fromList(key);
    try {
      transcoded = await _transcoder.transcode(request.source, keyCopy);
    } finally {
      keyCopy.fillRange(0, keyCopy.length, 0);
      await subscription.cancel();
    }
    if (transcoded is Failure<TranscodedVideo>) {
      return Failure(transcoded.error);
    }
    if (_cancelled) return _cancelledFailure;
    final video = (transcoded as Success<TranscodedVideo>).value;

    final invalid = _validate(video, maxDurationS);
    if (invalid != null) return Failure(invalid);
    final sizeMb = videoSizeMb(video.files.map((f) => f.bytes.length));

    final fresh = await _videos.quota();
    if (fresh is Failure<VideoQuota>) return Failure(fresh.error);
    final quota = (fresh as Success<VideoQuota>).value;
    if (quota.usedMb + sizeMb > quota.capMb) {
      return const Failure(AppError(ErrorCodes.quotaExceeded));
    }
    if (_cancelled) return _cancelledFailure;

    final created = await _uploads.createAsset(
      topicId: request.topicId,
      subtopicId: request.subtopicId,
      title: request.title.trim(),
      durationS: video.durationS,
      sizeMb: sizeMb,
    );
    if (created is Failure<String>) return Failure(created.error);
    final assetId = (created as Success<String>).value;

    final failure = await _uploadAndConfirm(
      assetId,
      video.files,
      videoKeyHex(key),
      report,
    );
    if (failure == null) {
      return Success(
        PublishedVideo(
          assetId: assetId,
          durationS: video.durationS,
          sizeMb: sizeMb,
        ),
      );
    }
    // Anything after the reservation must leave no pending row or objects.
    if (!await _deleteWithRetry(assetId)) {
      return Failure(AppError(ErrorCodes.videoCleanupFailed, failure.code));
    }
    return Failure(failure);
  }

  /// Deletes the reservation, up to [_cleanupAttempts] tries with a growing
  /// pause between them. Returns whether it was deleted.
  Future<bool> _deleteWithRetry(String assetId) async {
    for (var attempt = 1; attempt <= _cleanupAttempts; attempt++) {
      final result = await _videos.delete(assetId);
      if (result is! Failure<void>) return true;
      if (attempt < _cleanupAttempts) {
        await _delay(_cleanupBackoff * attempt);
      }
    }
    return false;
  }

  AppError? _validate(TranscodedVideo video, int? maxDurationS) {
    if (!validVideoDuration(video.durationS)) {
      return const AppError(ErrorCodes.videoTranscodeFailed);
    }
    if (maxDurationS != null && video.durationS > maxDurationS) {
      return const AppError(ErrorCodes.videoTooLong);
    }
    if (video.files.length > _maxFiles) {
      return const AppError(ErrorCodes.videoTooLong);
    }
    if (!video.files.any((f) => f.name == 'master.m3u8')) {
      return const AppError(ErrorCodes.videoTranscodeFailed);
    }
    return null;
  }

  /// Returns null on success, otherwise the error to report after rollback.
  Future<AppError?> _uploadAndConfirm(
    String assetId,
    List<HlsFile> files,
    String keyHex,
    void Function(PublishProgress) report,
  ) async {
    final names = files.map((f) => f.name).toList();
    final urls = await _uploads.uploadUrls(assetId, names);
    if (urls is Failure<Map<String, String>>) return urls.error;
    if (_cancelled) return const AppError(ErrorCodes.cancelled);
    report(PublishUploading(done: 0, total: files.length));
    final put = await _uploader.upload(
      files,
      (urls as Success<Map<String, String>>).value,
      onProgress: (done, total) =>
          report(PublishUploading(done: done, total: total)),
    );
    if (put is Failure<void>) return put.error;
    if (_cancelled) return const AppError(ErrorCodes.cancelled);
    report(const PublishFinalizing());
    final confirmed = await _uploads.confirm(assetId, keyHex);
    if (confirmed is Failure<void>) return confirmed.error;
    return null;
  }
}
