import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sat_east_client/core/di/injection.dart';
import 'package:sat_east_client/core/theme/app_theme.dart';
import 'package:sat_east_client/core/video/video_provider.dart';
import 'package:sat_east_client/features/teacher/videos/domain/entities/teacher_video.dart';
import 'package:sat_east_client/features/teacher/videos/domain/entities/video_quota.dart';
import 'package:sat_east_client/features/teacher/videos/presentation/cubit/teacher_videos_cubit.dart';
import 'package:sat_east_client/features/teacher/videos/presentation/cubit/teacher_videos_state.dart';
import 'package:sat_east_client/features/teacher/videos/presentation/screens/teacher_videos_screen.dart';

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
    when(
      () => cubit.addYoutube(
        title: any(named: 'title'),
        input: any(named: 'input'),
        durationS: any(named: 'durationS'),
      ),
    ).thenAnswer((_) async {});
    getIt.registerFactory<TeacherVideosCubit>(() => cubit);
  });
  tearDown(() => getIt.unregister<TeacherVideosCubit>());

  Future<void> pump(
    WidgetTester tester, {
    double width = 1280,
    bool empty = false,
    bool youtube = false,
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
              : youtube
              ? const [
                  TeacherVideo(
                    assetId: 'yt',
                    title: 'Intro',
                    durationS: 30,
                    provider: VideoProvider.youtube,
                    youtubeId: 'dQw4w9WgXcQ',
                    ready: true,
                    sort: 1,
                  ),
                ]
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
      expect(
        find.text('Upload protected videos with the video tool.'),
        findsOneWidget,
      );
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
  testWidgets('C-2: add dialog validates YouTube input and duration', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.text('Add YouTube video'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add').last);
    await tester.pumpAndSettle();
    expect(find.text('Paste a YouTube link or video id.'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('youtube-title')),
      'Intro',
    );
    await tester.enterText(
      find.byKey(const ValueKey('youtube-input')),
      'https://youtu.be/dQw4w9WgXcQ',
    );
    await tester.enterText(
      find.byKey(const ValueKey('youtube-duration')),
      '0:00',
    );
    await tester.tap(find.text('Add').last);
    await tester.pumpAndSettle();
    verifyNever(
      () => cubit.addYoutube(
        title: any(named: 'title'),
        input: any(named: 'input'),
        durationS: any(named: 'durationS'),
      ),
    );
    await tester.enterText(
      find.byKey(const ValueKey('youtube-duration')),
      '0:30',
    );
    await tester.tap(find.text('Add').last);
    await tester.pumpAndSettle();
    verify(
      () => cubit.addYoutube(
        title: 'Intro',
        input: 'https://youtu.be/dQw4w9WgXcQ',
        durationS: 30,
      ),
    ).called(1);
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
  testWidgets('C-2: YouTube card shows provider and dash size', (tester) async {
    await pump(tester, youtube: true);
    expect(find.text('YouTube'), findsOneWidget);
    expect(find.text('\u2014 '), findsOneWidget);
    expect(find.text('0:30'), findsOneWidget);
  });
  testWidgets('C-2: empty list keeps quota and add action visible', (
    tester,
  ) async {
    await pump(tester, empty: true);
    expect(find.text('No videos yet.'), findsOneWidget);
    expect(find.text('Add YouTube video'), findsOneWidget);
    expect(find.text('3.2 of 9 GB used'), findsOneWidget);
  });
}
