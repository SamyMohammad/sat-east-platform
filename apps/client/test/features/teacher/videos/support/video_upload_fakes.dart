import 'dart:async';
import 'dart:typed_data';

import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/teacher/videos/domain/entities/picked_video.dart';
import 'package:sat_east_client/features/teacher/videos/domain/entities/teacher_video.dart';
import 'package:sat_east_client/features/teacher/videos/domain/entities/video_quota.dart';
import 'package:sat_east_client/features/teacher/videos/domain/entities/video_upload.dart';
import 'package:sat_east_client/features/teacher/videos/domain/repositories/teacher_videos_repository.dart';
import 'package:sat_east_client/features/teacher/videos/domain/repositories/video_upload_repository.dart';
import 'package:sat_east_client/features/teacher/videos/domain/services/video_picker.dart';
import 'package:sat_east_client/features/teacher/videos/domain/services/video_transcoder.dart';
import 'package:sat_east_client/features/teacher/videos/domain/services/video_uploader.dart';

const kMb = 1048576;

PickedVideo pickedVideo({int sizeBytes = 10 * kMb}) =>
    PickedVideo(name: 'lesson.mp4', sizeBytes: sizeBytes, handle: Object());

List<HlsFile> hlsFiles({int segments = 2, int segmentBytes = 100}) => [
  HlsFile(name: 'master.m3u8', bytes: Uint8List(10)),
  HlsFile(name: '540p.m3u8', bytes: Uint8List(10)),
  for (var i = 0; i < segments; i++)
    HlsFile(
      name: '540p_${i.toString().padLeft(3, '0')}.ts',
      bytes: Uint8List(segmentBytes),
    ),
];

/// Shared call log so tests can assert ordering across fakes.
class CallLog {
  final calls = <String>[];
}

class FakeTeacherVideosRepository implements TeacherVideosRepository {
  FakeTeacherVideosRepository(this.log);
  final CallLog log;

  /// Returned in order; the last value repeats.
  List<VideoQuota> quotas = const [VideoQuota(usedMb: 0, capMb: 1000)];
  Result<VideoQuota>? quotaFailure;
  Result<void> deleteResult = const Success(null);

  /// Consumed one per delete call before falling back to [deleteResult].
  List<Result<void>> deleteResults = [];
  var _quotaCalls = 0;

  @override
  Future<Result<VideoQuota>> quota() async {
    log.calls.add('quota');
    if (quotaFailure != null) return quotaFailure!;
    final index = _quotaCalls < quotas.length ? _quotaCalls : quotas.length - 1;
    _quotaCalls++;
    return Success(quotas[index]);
  }

  @override
  Future<Result<void>> delete(String assetId) async {
    log.calls.add('delete:$assetId');
    if (deleteResults.isNotEmpty) return deleteResults.removeAt(0);
    return deleteResult;
  }

  @override
  Future<Result<List<TeacherVideo>>> list(String topicId) =>
      throw UnimplementedError();
  @override
  Future<Result<void>> update(
    String assetId,
    String title,
    String? subtopicId,
  ) => throw UnimplementedError();
  @override
  Future<Result<void>> reorder(String topicId, List<String> ids) =>
      throw UnimplementedError();
}

class FakeVideoUploadRepository implements VideoUploadRepository {
  FakeVideoUploadRepository(this.log);
  final CallLog log;
  Result<VideoUploadLimits> limitsResult = const Success(
    VideoUploadLimits(maxSourceMb: 500, maxDurationS: 900),
  );
  Result<String> createResult = const Success('asset-1');
  Result<Map<String, String>>? urlsResult;
  Result<void> confirmResult = const Success(null);
  Map<String, Object?>? created;
  String? confirmedKey;
  List<String>? requestedFiles;

  @override
  Future<Result<VideoUploadLimits>> limits() async {
    log.calls.add('limits');
    return limitsResult;
  }

  @override
  Future<Result<String>> createAsset({
    required String topicId,
    required String? subtopicId,
    required String title,
    required int durationS,
    required int sizeMb,
  }) async {
    log.calls.add('create');
    created = {
      'topicId': topicId,
      'subtopicId': subtopicId,
      'title': title,
      'durationS': durationS,
      'sizeMb': sizeMb,
    };
    return createResult;
  }

  @override
  Future<Result<Map<String, String>>> uploadUrls(
    String assetId,
    List<String> files,
  ) async {
    log.calls.add('urls');
    requestedFiles = files;
    return urlsResult ?? Success({for (final f in files) f: 'https://r2/$f'});
  }

  @override
  Future<Result<void>> confirm(String assetId, String keyHex) async {
    log.calls.add('confirm');
    confirmedKey = keyHex;
    return confirmResult;
  }
}

class FakeVideoTranscoder implements VideoTranscoder {
  FakeVideoTranscoder(this.log);
  final CallLog log;
  @override
  bool isSupported = true;
  Result<int> probeResult = const Success(120);
  Result<TranscodedVideo>? transcodeResult;
  List<double> progressEvents = const [];
  Completer<void>? gate;
  bool cancelled = false;
  Uint8List? receivedKey;
  final _progress = StreamController<double>.broadcast(sync: true);

  @override
  Stream<double> get progress => _progress.stream;

  @override
  Future<Result<int>> probeDuration(PickedVideo source) async {
    log.calls.add('probe');
    return probeResult;
  }

  @override
  Future<Result<TranscodedVideo>> transcode(
    PickedVideo source,
    Uint8List key,
  ) async {
    log.calls.add('transcode');
    receivedKey = key;
    progressEvents.forEach(_progress.add);
    // Mimics ffmpeg.writeFile detaching the buffer it was given.
    key.fillRange(0, key.length, 0);
    if (gate != null) await gate!.future;
    if (cancelled) return const Failure(AppError(ErrorCodes.cancelled));
    return transcodeResult ??
        Success(TranscodedVideo(files: hlsFiles(), durationS: 120));
  }

  @override
  Future<void> cancel() async {
    cancelled = true;
    if (gate != null && !gate!.isCompleted) gate!.complete();
  }
}

class FakeVideoUploader implements VideoUploader {
  FakeVideoUploader(this.log);
  final CallLog log;
  Result<void> result = const Success(null);
  Completer<void>? gate;
  bool cancelled = false;
  Map<String, String>? receivedUrls;
  int reportDone = 0;

  @override
  Future<Result<void>> upload(
    List<HlsFile> files,
    Map<String, String> urls, {
    void Function(int done, int total)? onProgress,
  }) async {
    log.calls.add('upload');
    receivedUrls = urls;
    if (reportDone > 0) onProgress?.call(reportDone, files.length);
    if (gate != null) await gate!.future;
    if (cancelled) return const Failure(AppError(ErrorCodes.cancelled));
    return result;
  }

  @override
  void cancel() {
    cancelled = true;
    if (gate != null && !gate!.isCompleted) gate!.complete();
  }
}

class FakeVideoPicker implements VideoPicker {
  @override
  bool isSupported = true;
  Result<PickedVideo> result = Success(pickedVideo());
  int picks = 0;

  @override
  Future<Result<PickedVideo>> pick() async {
    picks++;
    return result;
  }
}
