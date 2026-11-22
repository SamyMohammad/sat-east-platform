import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/di/injection.dart';
import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/core/theme/app_theme.dart';
import 'package:sat_east_client/features/teacher/videos/domain/entities/video_upload.dart';
import 'package:sat_east_client/features/teacher/videos/domain/usecases/publish_video.dart';
import 'package:sat_east_client/features/teacher/videos/presentation/cubit/upload_video_cubit.dart';
import 'package:sat_east_client/features/teacher/videos/presentation/widgets/upload_video_dialog.dart';

import '../support/video_upload_fakes.dart';

void main() {
  late CallLog log;
  late FakeVideoPicker picker;
  late FakeTeacherVideosRepository videos;
  late FakeVideoUploadRepository uploads;
  late FakeVideoTranscoder transcoder;
  late FakeVideoUploader uploader;
  var published = 0;

  setUp(() {
    log = CallLog();
    picker = FakeVideoPicker();
    videos = FakeTeacherVideosRepository(log);
    uploads = FakeVideoUploadRepository(log);
    transcoder = FakeVideoTranscoder(log);
    uploader = FakeVideoUploader(log);
    published = 0;
    getIt.registerFactory<UploadVideoCubit>(
      () => UploadVideoCubit(
        picker: picker,
        uploads: uploads,
        publish: PublishVideo(
          videos: videos,
          uploads: uploads,
          transcoder: transcoder,
          uploader: uploader,
          randomKey: () => Uint8List.fromList(List<int>.filled(16, 1)),
        ),
      ),
    );
  });
  tearDown(() => getIt.unregister<UploadVideoCubit>());

  Future<void> open(WidgetTester tester, {double width = 1280}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, 900);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => unawaited(
                  showUploadVideoDialog(
                    context,
                    topicId: 't',
                    onPublished: () => published++,
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  // The fakes finish on real microtask turns; let them run, then settle.
  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pumpAndSettle();
  }

  Future<void> chooseAndTitle(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('upload-choose-file')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('upload-title')),
      'Lesson one',
    );
  }

  for (final width in [360.0, 1280.0]) {
    testWidgets('VID-01: idle form fits $width with limits and warning', (
      tester,
    ) async {
      await open(tester, width: width);
      expect(find.text('No file chosen'), findsOneWidget);
      expect(
        find.text('Video limits: up to 500 MB, up to 15 min.'),
        findsOneWidget,
      );
      expect(
        find.text('Keep this tab open until the upload finishes.'),
        findsOneWidget,
      );
      expect(find.textContaining('longer than the video'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('VID-01: running state fits $width', (tester) async {
      transcoder
        ..gate = Completer<void>()
        ..progressEvents = const [0.4];
      await open(tester, width: width);
      await chooseAndTitle(tester);
      await tester.tap(find.text('Upload'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Converting video'), findsOneWidget);
      expect(find.text('40%'), findsOneWidget);
      expect(
        find.text('Keep this tab open until the upload finishes.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      transcoder.gate!.complete();
      transcoder.cancelled = true;
      await tester.pumpAndSettle();
    });
  }

  testWidgets('VID-01: unsupported platform says upload from the web', (
    tester,
  ) async {
    picker.isSupported = false;
    await open(tester);
    expect(find.text('Upload videos from the web dashboard.'), findsOneWidget);
    expect(find.byKey(const ValueKey('upload-choose-file')), findsNothing);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Upload videos from the web dashboard.'), findsNothing);
  });

  testWidgets('VID-01: title is validated before any upload starts', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.byKey(const ValueKey('upload-choose-file')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Upload'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a title.'), findsOneWidget);
    expect(log.calls, isNot(contains('create')));
    expect(log.calls, isNot(contains('transcode')));
  });

  testWidgets('VID-01: Upload is disabled until a file is chosen', (
    tester,
  ) async {
    await open(tester);
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Upload'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('VID-01: success reports published and closes with Done', (
    tester,
  ) async {
    await open(tester);
    await chooseAndTitle(tester);
    await tester.tap(find.text('Upload'));
    await tester.pumpAndSettle();
    await settle(tester);
    expect(find.text('Video uploaded.'), findsOneWidget);
    expect(published, 1);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('Video uploaded.'), findsNothing);
  });

  testWidgets('VID-01: failure shows English copy, never the raw code', (
    tester,
  ) async {
    uploads.limitsResult = const Success(VideoUploadLimits(maxSourceMb: 5));
    await open(tester);
    await chooseAndTitle(tester);
    await tester.tap(find.text('Upload'));
    await settle(tester);
    expect(
      find.text('That file is too large. Choose a smaller video.'),
      findsOneWidget,
    );
    expect(find.textContaining('video_too_large'), findsNothing);
    expect(published, 0);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('upload-title')), findsOneWidget);
  });

  testWidgets('VID-01: barrier tap cannot dismiss a running upload', (
    tester,
  ) async {
    transcoder.gate = Completer<void>();
    await open(tester);
    await chooseAndTitle(tester);
    await tester.tap(find.text('Upload'));
    await tester.pump();
    await tester.pump();
    await tester.tapAt(const Offset(5, 5));
    await tester.pump();
    expect(find.text('Converting video'), findsOneWidget);
    transcoder.gate!.complete();
    transcoder.cancelled = true;
    await tester.pumpAndSettle();
  });

  testWidgets('VID-01: stop asks for confirmation and can be declined', (
    tester,
  ) async {
    transcoder.gate = Completer<void>();
    await open(tester);
    await chooseAndTitle(tester);
    await tester.tap(find.text('Upload'));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.text('Stop upload'));
    await tester.pumpAndSettle();
    expect(find.text('Stop the upload?'), findsOneWidget);
    await tester.tap(find.text('Keep uploading'));
    await tester.pumpAndSettle();
    expect(transcoder.cancelled, isFalse);
    expect(find.text('Converting video'), findsOneWidget);

    await tester.tap(find.text('Stop upload'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Stop upload').last);
    await settle(tester);
    expect(transcoder.cancelled, isTrue);
    expect(find.byKey(const ValueKey('upload-title')), findsOneWidget);
    expect(find.text(ErrorCodes.cancelled), findsNothing);
  });
}
