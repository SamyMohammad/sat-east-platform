import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/teacher/videos/domain/entities/video_quota.dart';
import 'package:sat_east_client/features/teacher/videos/domain/entities/video_upload.dart';
import 'package:sat_east_client/features/teacher/videos/domain/usecases/publish_video.dart';

import '../support/video_upload_fakes.dart';

void main() {
  late CallLog log;
  late FakeTeacherVideosRepository videos;
  late FakeVideoUploadRepository uploads;
  late FakeVideoTranscoder transcoder;
  late FakeVideoUploader uploader;
  late PublishVideo publish;
  final key = Uint8List.fromList(List.generate(16, (i) => i + 1));
  const keyHex = '0102030405060708090a0b0c0d0e0f10';

  PublishVideoRequest request({int sizeBytes = 10 * kMb, String? title}) =>
      PublishVideoRequest(
        topicId: 'topic-1',
        subtopicId: 'sub-1',
        title: title ?? '  Lesson  ',
        source: pickedVideo(sizeBytes: sizeBytes),
      );

  late List<Duration> delays;
  const networkFailure = Failure<void>(AppError(ErrorCodes.network));

  setUp(() {
    delays = [];
    log = CallLog();
    videos = FakeTeacherVideosRepository(log);
    uploads = FakeVideoUploadRepository(log);
    transcoder = FakeVideoTranscoder(log);
    uploader = FakeVideoUploader(log);
    publish = PublishVideo(
      videos: videos,
      uploads: uploads,
      transcoder: transcoder,
      uploader: uploader,
      randomKey: () => Uint8List.fromList(key),
      delay: (d) async => delays.add(d),
    );
  });

  String errorCode(Result<PublishedVideo> r) =>
      (r as Failure<PublishedVideo>).error.code;

  test('VID-01: happy path mirrors publish.ts order', () async {
    final result = await publish(request());
    final value = (result as Success<PublishedVideo>).value;
    expect(value.assetId, 'asset-1');
    expect(value.durationS, 120);
    expect(value.sizeMb, 1);
    expect(log.calls, [
      'limits',
      'probe',
      'quota',
      'transcode',
      'quota',
      'create',
      'urls',
      'upload',
      'confirm',
    ]);
    expect(uploads.created, {
      'topicId': 'topic-1',
      'subtopicId': 'sub-1',
      'title': 'Lesson',
      'durationS': 120,
      'sizeMb': 1,
    });
    expect(uploads.requestedFiles, [
      'master.m3u8',
      '540p.m3u8',
      '540p_000.ts',
      '540p_001.ts',
    ]);
    expect(uploader.receivedUrls!.keys, uploads.requestedFiles);
  });

  test(
    'VID-01: the key reaches confirm after the transcoder detaches its copy',
    () async {
      await publish(request());
      expect(transcoder.receivedKey, everyElement(0));
      expect(uploads.confirmedKey, keyHex);
    },
  );

  test(
    'VID-01: size_mb rounds up to a whole MB like sizeMb in publish.ts',
    () async {
      transcoder.transcodeResult = Success(
        TranscodedVideo(
          files: [
            HlsFile(name: 'master.m3u8', bytes: Uint8List(kMb)),
            HlsFile(name: '540p.m3u8', bytes: Uint8List(1)),
          ],
          durationS: 30,
        ),
      );
      await publish(request());
      expect(uploads.created!['sizeMb'], 2);
    },
  );

  test('VID-01: unsupported platform fails before any network call', () async {
    transcoder.isSupported = false;
    expect(errorCode(await publish(request())), ErrorCodes.unsupported);
    expect(log.calls, isEmpty);
  });

  test('VID-01: invalid title is rejected locally', () async {
    expect(
      errorCode(await publish(request(title: '   '))),
      ErrorCodes.invalidInput,
    );
    expect(
      errorCode(await publish(request(title: 'x' * 121))),
      ErrorCodes.invalidInput,
    );
    expect(log.calls, isEmpty);
  });

  test(
    'VID-01: source above video_upload_max_source_mb is rejected first',
    () async {
      final result = await publish(request(sizeBytes: 501 * kMb));
      expect(errorCode(result), ErrorCodes.videoTooLarge);
      expect(log.calls, ['limits']);
    },
  );

  test('VID-01: source exactly at the size limit is accepted', () async {
    final result = await publish(request(sizeBytes: 500 * kMb));
    expect(result, isA<Success<PublishedVideo>>());
  });

  test(
    'VID-01: probed duration above the limit is rejected before transcoding',
    () async {
      transcoder.probeResult = const Success(901);
      expect(errorCode(await publish(request())), ErrorCodes.videoTooLong);
      expect(log.calls, ['limits', 'probe']);
    },
  );

  test(
    'VID-01: unknown probe duration defers to the transcoded duration',
    () async {
      transcoder
        ..probeResult = const Failure(AppError(ErrorCodes.internal))
        ..transcodeResult = Success(
          TranscodedVideo(files: hlsFiles(), durationS: 1200),
        );
      expect(errorCode(await publish(request())), ErrorCodes.videoTooLong);
      expect(log.calls, contains('transcode'));
      expect(log.calls, isNot(contains('create')));
    },
  );

  test('VID-01: missing settings mean no client-side limit', () async {
    uploads.limitsResult = const Success(VideoUploadLimits());
    final result = await publish(request(sizeBytes: 900 * kMb));
    expect(result, isA<Success<PublishedVideo>>());
  });

  test(
    'VID-01: unreadable settings fail the upload instead of skipping checks',
    () async {
      uploads.limitsResult = const Failure(AppError(ErrorCodes.network));
      expect(errorCode(await publish(request())), ErrorCodes.network);
      expect(log.calls, ['limits']);
    },
  );

  test('VID-01: quota read failure stops the upload', () async {
    videos.quotaFailure = const Failure(AppError(ErrorCodes.network));
    expect(errorCode(await publish(request())), ErrorCodes.network);
    expect(log.calls, isNot(contains('transcode')));
  });

  test('VID-01: full quota stops before transcoding', () async {
    videos.quotas = const [VideoQuota(usedMb: 1000, capMb: 1000)];
    expect(errorCode(await publish(request())), ErrorCodes.quotaExceeded);
    expect(log.calls, isNot(contains('transcode')));
  });

  test(
    'VID-01: transcoded size over the remaining quota reserves nothing',
    () async {
      videos.quotas = const [
        VideoQuota(usedMb: 0, capMb: 1000),
        VideoQuota(usedMb: 999, capMb: 1000),
      ];
      transcoder.transcodeResult = Success(
        TranscodedVideo(
          files: [HlsFile(name: 'master.m3u8', bytes: Uint8List(3 * kMb))],
          durationS: 60,
        ),
      );
      expect(errorCode(await publish(request())), ErrorCodes.quotaExceeded);
      expect(log.calls, isNot(contains('create')));
    },
  );

  test(
    'VID-01: a quota_exceeded reservation is returned and nothing is deleted',
    () async {
      uploads.createResult = const Failure(AppError(ErrorCodes.quotaExceeded));
      expect(errorCode(await publish(request())), ErrorCodes.quotaExceeded);
      expect(log.calls, isNot(contains('urls')));
      expect(log.calls.where((c) => c.startsWith('delete')), isEmpty);
    },
  );

  test('VID-01: transcode failure reserves nothing', () async {
    transcoder.transcodeResult = const Failure(
      AppError(ErrorCodes.videoTranscodeFailed),
    );
    expect(
      errorCode(await publish(request())),
      ErrorCodes.videoTranscodeFailed,
    );
    expect(log.calls, isNot(contains('create')));
  });

  test('VID-01: output without master.m3u8 is a transcode failure', () async {
    transcoder.transcodeResult = Success(
      TranscodedVideo(
        files: [HlsFile(name: '540p.m3u8', bytes: Uint8List(5))],
        durationS: 60,
      ),
    );
    expect(
      errorCode(await publish(request())),
      ErrorCodes.videoTranscodeFailed,
    );
    expect(log.calls, isNot(contains('create')));
  });

  test('VID-01: more than 2000 files is rejected like the CLI', () async {
    transcoder.transcodeResult = Success(
      TranscodedVideo(files: hlsFiles(segments: 2000), durationS: 60),
    );
    expect(errorCode(await publish(request())), ErrorCodes.videoTooLong);
    expect(log.calls, isNot(contains('create')));
  });

  test('VID-01: URL request failure deletes the reservation', () async {
    uploads.urlsResult = const Failure(AppError(ErrorCodes.internal));
    expect(errorCode(await publish(request())), ErrorCodes.internal);
    expect(log.calls.last, 'delete:asset-1');
  });

  test(
    'VID-01: PUT failure deletes the reservation and reports the upload error',
    () async {
      uploader.result = const Failure(AppError(ErrorCodes.videoUploadFailed));
      expect(errorCode(await publish(request())), ErrorCodes.videoUploadFailed);
      expect(log.calls, containsAllInOrder(['upload', 'delete:asset-1']));
      expect(log.calls, isNot(contains('confirm')));
    },
  );

  test('VID-01: confirm failure deletes the reservation', () async {
    uploads.confirmResult = const Failure(AppError(ErrorCodes.internal));
    expect(errorCode(await publish(request())), ErrorCodes.internal);
    expect(log.calls.last, 'delete:asset-1');
  });

  test('VID-01: failed cleanup is reported as video_cleanup_failed', () async {
    uploader.result = const Failure(AppError(ErrorCodes.videoUploadFailed));
    videos.deleteResult = const Failure(AppError(ErrorCodes.network));
    expect(errorCode(await publish(request())), ErrorCodes.videoCleanupFailed);
  });

  test(
    'VID-01: cleanup retried, succeeds on 3rd delete, original error returned',
    () async {
      uploader.result = const Failure(AppError(ErrorCodes.videoUploadFailed));
      videos.deleteResults = [networkFailure, networkFailure];
      expect(errorCode(await publish(request())), ErrorCodes.videoUploadFailed);
      expect(log.calls.where((c) => c.startsWith('delete')).length, 3);
    },
  );

  test(
    'VID-01: cleanup failing 3 times is video_cleanup_failed with backoff',
    () async {
      uploader.result = const Failure(AppError(ErrorCodes.videoUploadFailed));
      videos.deleteResult = networkFailure;
      expect(
        errorCode(await publish(request())),
        ErrorCodes.videoCleanupFailed,
      );
      expect(log.calls.where((c) => c.startsWith('delete')).length, 3);
      expect(delays.length, 2);
      expect(delays[1], greaterThan(delays[0]));
    },
  );

  test('VID-01: cleanup after cancel is retried too', () async {
    uploader.gate = Completer<void>();
    videos.deleteResults = [networkFailure];
    final future = publish(request());
    await pumpEventQueue();
    await publish.cancel();
    expect(errorCode(await future), ErrorCodes.cancelled);
    expect(log.calls.where((c) => c.startsWith('delete')).length, 2);
    expect(delays.length, 1);
  });

  test('VID-01: cancelling during transcoding reserves nothing', () async {
    transcoder.gate = Completer<void>();
    final future = publish(request());
    await pumpEventQueue();
    await publish.cancel();
    expect(errorCode(await future), ErrorCodes.cancelled);
    expect(log.calls, isNot(contains('create')));
  });

  test('VID-01: cancelling during upload deletes the reservation', () async {
    uploader.gate = Completer<void>();
    final future = publish(request());
    await pumpEventQueue();
    await publish.cancel();
    expect(errorCode(await future), ErrorCodes.cancelled);
    expect(log.calls.last, 'delete:asset-1');
    expect(log.calls, isNot(contains('confirm')));
  });

  test('VID-01: progress is reported for each phase', () async {
    transcoder.progressEvents = const [0.25, 0.5, 1.5];
    uploader.reportDone = 2;
    final events = <PublishProgress>[];
    await publish(request(), onProgress: events.add);
    expect(events, const [
      PublishChecking(),
      PublishTranscoding(0),
      PublishTranscoding(0.25),
      PublishTranscoding(0.5),
      PublishTranscoding(1),
      PublishUploading(done: 0, total: 4),
      PublishUploading(done: 2, total: 4),
      PublishFinalizing(),
    ]);
  });
}
