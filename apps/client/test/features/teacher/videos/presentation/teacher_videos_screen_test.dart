import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sat_east_client/core/di/injection.dart';
import 'package:sat_east_client/core/theme/app_theme.dart';
import 'package:sat_east_client/core/video/video_provider.dart';
import 'package:sat_east_client/features/teacher/videos/domain/entities/teacher_video.dart';
import 'package:sat_east_client/features/teacher/videos/domain/entities/video_quota.dart';
import 'package:sat_east_client/features/teacher/videos/domain/usecases/publish_video.dart';
import 'package:sat_east_client/features/teacher/videos/presentation/cubit/teacher_videos_cubit.dart';
import 'package:sat_east_client/features/teacher/videos/presentation/cubit/teacher_videos_state.dart';
import 'package:sat_east_client/features/teacher/videos/presentation/cubit/upload_video_cubit.dart';
import 'package:sat_east_client/features/teacher/videos/presentation/screens/teacher_videos_screen.dart';

import '../support/video_upload_fakes.dart';

class _Cubit extends MockCubit<TeacherVideosState>
    implements TeacherVideosCubit {}

void main() {
  late _Cubit cubit;
  setUp(() {
    cubit = _Cubit();
    when(() => cubit.load(any())).thenAnswer((_) async {});
    when(cubit.close).thenAnswer((_) async {});
    when(() => cubit.delete(any())).thenAnswer((_) async {});
    when(() => cubit.rename(any(), any())).thenAnswer((_) async {});
    getIt
      ..registerFactory<TeacherVideosCubit>(() => cubit)
      ..registerFactory<UploadVideoCubit>(() {
        final log = CallLog();
        final uploads = FakeVideoUploadRepository(log);
        return UploadVideoCubit(
          picker: FakeVideoPicker(),
          uploads: uploads,
          publish: PublishVideo(
            videos: FakeTeacherVideosRepository(log),
            uploads: uploads,
            transcoder: FakeVideoTranscoder(log),
            uploader: FakeVideoUploader(log),
          ),
        );
      });
  });
  tearDown(() async {
    await getIt.unregister<TeacherVideosCubit>();
    await getIt.unregister<UploadVideoCubit>();
  });

  Future<void> pump(
    WidgetTester tester, {
    double width = 1280,
    bool empty = false,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, 1000);
    addTearDown(tester.view.reset);
    whenListen(
      cubit,
      const Stream<TeacherVideosState>.empty(),
      initialState: TeacherVideosReady(
        TeacherVideosData(
          videos: empty
              ? []
              : const [
                  TeacherVideo(
                    assetId: 'a',
                    title: 'Lesson',
                    durationS: 600,
                    sizeMb: 12,
                    provider: VideoProvider.r2Hls,
                    ready: true,
                    sort: 1,
                  ),
                  TeacherVideo(
                    assetId: 'pending',
                    title: 'Pending',
                    durationS: 60,
                    sizeMb: 1,
                    provider: VideoProvider.r2Hls,
                    ready: false,
                    sort: 2,
                  ),
                ],
          quota: const VideoQuota(usedMb: 3277, capMb: 9216),
        ),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: TeacherVideosScreen(courseId: 'c', topicId: 't'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  }

  for (final width in [360.0, 1280.0]) {
    testWidgets('C-2: Videos manager fits $width and pending has only Delete', (
      tester,
    ) async {
      await pump(tester, width: width);
      expect(find.text('3.2 of 9 GB used'), findsOneWidget);
      expect(find.text('Upload video'), findsOneWidget);
      expect(find.textContaining('YouTube'), findsNothing);
      expect(find.textContaining('video tool'), findsNothing);
      expect(find.textContaining('10:00'), findsOneWidget);
      expect(find.text('Upload not finished'), findsOneWidget);
      final pending = find.byKey(const ValueKey('video-pending'));
      expect(
        find.descendant(of: pending, matching: find.byType(IconButton)),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('rename-pending')), findsNothing);
      expect(find.byKey(const ValueKey('up-pending')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('C-2: delete requires confirmation with the progress warning', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.byKey(const ValueKey('delete-a')));
    await tester.pumpAndSettle();
    expect(
      find.text('Delete this video? Students lose their progress on it.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    verifyNever(() => cubit.delete('a'));
    await tester.tap(find.byKey(const ValueKey('delete-a')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();
    verify(() => cubit.delete('a')).called(1);
  });
  testWidgets('C-2: rename dialog saves through the Cubit', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const ValueKey('rename-a')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Changed');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    verify(() => cubit.rename('a', 'Changed')).called(1);
  });
  testWidgets('C-2: empty list keeps quota and add action visible', (
    tester,
  ) async {
    await pump(tester, empty: true);
    expect(find.text('No videos yet.'), findsOneWidget);
    expect(find.text('Upload video'), findsOneWidget);
    expect(find.text('3.2 of 9 GB used'), findsOneWidget);
  });
  testWidgets('VID-01: Upload video opens the upload dialog', (tester) async {
    await pump(tester, width: 360);
    await tester.tap(find.text('Upload video'));
    await tester.pumpAndSettle();
    expect(find.text('Choose video file'), findsOneWidget);
    expect(
      find.text('Keep this tab open until the upload finishes.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Choose video file'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
