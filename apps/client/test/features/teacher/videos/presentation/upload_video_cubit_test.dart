import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/teacher/videos/domain/entities/video_quota.dart';
import 'package:sat_east_client/features/teacher/videos/domain/entities/video_upload.dart';
import 'package:sat_east_client/features/teacher/videos/domain/usecases/publish_video.dart';
import 'package:sat_east_client/features/teacher/videos/presentation/cubit/upload_video_cubit.dart';
import 'package:sat_east_client/features/teacher/videos/presentation/cubit/upload_video_state.dart';

import '../support/video_upload_fakes.dart';

void main() {
  late CallLog log;
  late FakeVideoPicker picker;
  late FakeTeacherVideosRepository videos;
  late FakeVideoUploadRepository uploads;
  late FakeVideoTranscoder transcoder;
  late FakeVideoUploader uploader;
  late UploadVideoCubit cubit;
  late List<UploadVideoState> states;
  late StreamSubscription<UploadVideoState> sub;

  UploadVideoCubit buildCubit() {
    final built = UploadVideoCubit(
      picker: picker,
      uploads: uploads,
      publish: PublishVideo(
        videos: videos,
        uploads: uploads,
        transcoder: transcoder,
        uploader: uploader,
        randomKey: () => Uint8List.fromList(List<int>.filled(16, 7)),
      ),
    );
    states = [];
    sub = built.stream.listen(states.add);
    return built;
  }

  setUp(() {
    log = CallLog();
    picker = FakeVideoPicker();
    videos = FakeTeacherVideosRepository(log);
    uploads = FakeVideoUploadRepository(log);
    transcoder = FakeVideoTranscoder(log);
    uploader = FakeVideoUploader(log);
    cubit = buildCubit();
  });
  tearDown(() async {
    await sub.cancel();
    await cubit.close();
  });

  Future<void> pickAndUpload({String title = 'Lesson one'}) async {
    await cubit.pickFile();
    await cubit.upload(topicId: 't', title: title);
  }

  UploadVideoError errorOf() => cubit.state as UploadVideoError;

  test('VID-01: unsupported picker starts in Unsupported', () async {
    await sub.cancel();
    await cubit.close();
    picker.isSupported = false;
    cubit = buildCubit();
    expect(cubit.state, isA<UploadVideoUnsupported>());
    await cubit.pickFile();
    expect(picker.picks, 0);
  });

  test('VID-01: loadLimits shows server limits on the idle state', () async {
    await cubit.loadLimits();
    final idle = cubit.state as UploadVideoIdle;
    expect(
      idle.limits,
      const VideoUploadLimits(maxSourceMb: 500, maxDurationS: 900),
    );
  });

  test(
    'VID-01: loadLimits failure leaves limits unknown, not an error',
    () async {
      uploads.limitsResult = const Failure(AppError(ErrorCodes.network));
      await cubit.loadLimits();
      expect((cubit.state as UploadVideoIdle).limits, isNull);
    },
  );

  test('VID-01: pickFile emits Picking then Idle with the file', () async {
    await cubit.pickFile();
    expect(states.first, isA<UploadVideoPicking>());
    expect((cubit.state as UploadVideoIdle).file?.name, 'lesson.mp4');
  });

  test('VID-01: cancelled chooser keeps the previous file silently', () async {
    await cubit.pickFile();
    picker.result = const Failure(AppError(ErrorCodes.cancelled));
    await cubit.pickFile();
    final idle = cubit.state as UploadVideoIdle;
    expect(idle.file?.name, 'lesson.mp4');
    expect(idle.error, isNull);
  });

  test('VID-01: chooser failure is reported with its code', () async {
    picker.result = const Failure(AppError(ErrorCodes.internal));
    await cubit.pickFile();
    expect((cubit.state as UploadVideoIdle).error?.code, ErrorCodes.internal);
  });

  test('VID-01: upload without a file does nothing', () async {
    await cubit.upload(topicId: 't', title: 'Lesson');
    expect(states, isEmpty);
    expect(log.calls, isEmpty);
  });

  test(
    'VID-01: success walks checking, transcoding, uploading, success',
    () async {
      transcoder.progressEvents = const [0.5];
      uploader.reportDone = 2;
      await pickAndUpload();
      await Future<void>.delayed(Duration.zero);
      final progress = [
        for (final s in states)
          if (s is UploadVideoRunning) s.progress,
      ];
      expect(progress.first, const PublishChecking());
      expect(progress, contains(const PublishTranscoding(0.5)));
      expect(progress, contains(const PublishUploading(done: 2, total: 4)));
      expect(progress.last, const PublishFinalizing());
      final done = cubit.state as UploadVideoSuccess;
      expect(done.video.assetId, 'asset-1');
      expect(uploads.created?['title'], 'Lesson one');
      expect(uploads.created?['topicId'], 't');
    },
  );

  test(
    'VID-01: upload trims nothing client-side but rejects a blank title',
    () async {
      await pickAndUpload(title: '   ');
      expect(errorOf().error.code, ErrorCodes.invalidInput);
      expect(log.calls, isNot(contains('create')));
    },
  );

  group('error mapping from PublishVideo', () {
    test('video_too_large', () async {
      uploads.limitsResult = const Success(VideoUploadLimits(maxSourceMb: 5));
      await pickAndUpload();
      expect(errorOf().error.code, ErrorCodes.videoTooLarge);
    });

    test('video_too_long from the probe', () async {
      transcoder.probeResult = const Success(5000);
      await pickAndUpload();
      expect(errorOf().error.code, ErrorCodes.videoTooLong);
    });

    test('video_transcode_failed', () async {
      transcoder.transcodeResult = const Failure(
        AppError(ErrorCodes.videoTranscodeFailed),
      );
      await pickAndUpload();
      expect(errorOf().error.code, ErrorCodes.videoTranscodeFailed);
    });

    test('video_engine_load_failed', () async {
      transcoder.transcodeResult = const Failure(
        AppError(ErrorCodes.videoEngineLoadFailed),
      );
      await pickAndUpload();
      expect(errorOf().error.code, ErrorCodes.videoEngineLoadFailed);
    });

    test('quota_exceeded', () async {
      videos.quotas = const [VideoQuota(usedMb: 1000, capMb: 1000)];
      await pickAndUpload();
      expect(errorOf().error.code, ErrorCodes.quotaExceeded);
    });

    test('video_upload_failed rolls back the reservation', () async {
      uploader.result = const Failure(AppError(ErrorCodes.videoUploadFailed));
      await pickAndUpload();
      expect(errorOf().error.code, ErrorCodes.videoUploadFailed);
      expect(log.calls, contains('delete:asset-1'));
    });

    test('video_cleanup_failed when rollback fails', () async {
      uploader.result = const Failure(AppError(ErrorCodes.videoUploadFailed));
      videos.deleteResult = const Failure(AppError(ErrorCodes.network));
      await pickAndUpload();
      expect(errorOf().error.code, ErrorCodes.videoCleanupFailed);
    });

    test('unsupported transcoder', () async {
      transcoder.isSupported = false;
      await pickAndUpload();
      expect(errorOf().error.code, ErrorCodes.unsupported);
    });
  });

  test('VID-01: dismissError returns to Idle keeping the file', () async {
    transcoder.transcodeResult = const Failure(
      AppError(ErrorCodes.videoTranscodeFailed),
    );
    await pickAndUpload();
    cubit.dismissError();
    final idle = cubit.state as UploadVideoIdle;
    expect(idle.file?.name, 'lesson.mp4');
    expect(idle.error, isNull);
  });

  test(
    'VID-01: cancel while transcoding returns to Idle with nothing created',
    () async {
      transcoder.gate = Completer<void>();
      await cubit.pickFile();
      final running = cubit.upload(topicId: 't', title: 'Lesson');
      await Future<void>.delayed(Duration.zero);
      await cubit.cancel();
      await running;
      expect(cubit.state, isA<UploadVideoIdle>());
      expect((cubit.state as UploadVideoIdle).file, isNotNull);
      expect(log.calls, isNot(contains('create')));
    },
  );

  test('VID-01: cancel while uploading deletes the reservation', () async {
    uploader.gate = Completer<void>();
    await cubit.pickFile();
    final running = cubit.upload(topicId: 't', title: 'Lesson');
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    await cubit.cancel();
    await running;
    expect(log.calls, contains('delete:asset-1'));
    expect(cubit.state, isA<UploadVideoIdle>());
  });

  test('VID-01: a second upload while running is ignored', () async {
    transcoder.gate = Completer<void>();
    await cubit.pickFile();
    final first = cubit.upload(topicId: 't', title: 'Lesson');
    await Future<void>.delayed(Duration.zero);
    await cubit.upload(topicId: 't', title: 'Other');
    expect(log.calls.where((c) => c == 'transcode'), hasLength(1));
    await cubit.cancel();
    await first;
  });

  test(
    'VID-01: closing while running cancels and emits nothing after',
    () async {
      transcoder.gate = Completer<void>();
      await cubit.pickFile();
      final running = cubit.upload(topicId: 't', title: 'Lesson');
      await Future<void>.delayed(Duration.zero);
      await cubit.close();
      await running;
      expect(transcoder.cancelled, isTrue);
    },
  );
}
