import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/core/video/video_provider.dart';
import 'package:sat_east_client/features/teacher/videos/domain/entities/teacher_video.dart';
import 'package:sat_east_client/features/teacher/videos/domain/entities/video_quota.dart';
import 'package:sat_east_client/features/teacher/videos/domain/repositories/teacher_videos_repository.dart';
import 'package:sat_east_client/features/teacher/videos/presentation/cubit/teacher_videos_cubit.dart';
import 'package:sat_east_client/features/teacher/videos/presentation/cubit/teacher_videos_state.dart';

class _Repo extends Mock implements TeacherVideosRepository {}

const _videos = [
  TeacherVideo(
    assetId: 'a',
    title: 'Lesson',
    subtopicId: 's',
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
  TeacherVideo(
    assetId: 'b',
    title: 'YouTube',
    durationS: 30,
    provider: VideoProvider.youtube,
    youtubeId: 'dQw4w9WgXcQ',
    ready: true,
    sort: 3,
  ),
];

void main() {
  late _Repo repo;
  late TeacherVideosCubit cubit;
  setUpAll(() => registerFallbackValue(<String>[]));
  setUp(() {
    repo = _Repo();
    cubit = TeacherVideosCubit(repo);
    when(
      () => repo.list(any()),
    ).thenAnswer((_) async => const Success(_videos));
    when(repo.quota).thenAnswer(
      (_) async => const Success(VideoQuota(usedMb: 3277, capMb: 9216)),
    );
    when(
      () => repo.addYoutube(any(), any(), any(), any()),
    ).thenAnswer((_) async => const Success(null));
    when(
      () => repo.update(any(), any(), any()),
    ).thenAnswer((_) async => const Success(null));
    when(
      () => repo.reorder(any(), any()),
    ).thenAnswer((_) async => const Success(null));
    when(() => repo.delete(any())).thenAnswer((_) async => const Success(null));
  });
  tearDown(() => cubit.close());
  test('C-2: load reads all videos and quota', () async {
    await cubit.load('t');
    final ready = cubit.state as TeacherVideosReady;
    expect(ready.data.videos, _videos);
    expect(ready.data.quota.label, '3.2 of 9 GB used');
  });
  test('C-2: list failure emits Failed and can reload', () async {
    when(
      () => repo.list('t'),
    ).thenAnswer((_) async => const Failure(AppError('forbidden')));
    await cubit.load('t');
    expect((cubit.state as TeacherVideosFailed).error.code, 'forbidden');
    when(() => repo.list('t')).thenAnswer((_) async => const Success(_videos));
    await cubit.load('t');
    expect(cubit.state, isA<TeacherVideosReady>());
  });
  test('C-2: quota failure prevents partially loaded state', () async {
    when(
      repo.quota,
    ).thenAnswer((_) async => const Failure(AppError('network')));
    await cubit.load('t');
    expect((cubit.state as TeacherVideosFailed).error.code, 'network');
  });
  test(
    'C-2: moveDown sends full reordered list including pending rows',
    () async {
      await cubit.load('t');
      await cubit.moveDown('a');
      verify(() => repo.reorder('t', ['pending', 'a', 'b'])).called(1);
      verify(() => repo.list('t')).called(2);
      verify(repo.quota).called(2);
    },
  );
  test('C-2: moveUp sends full list and boundary moves do nothing', () async {
    await cubit.load('t');
    await cubit.moveUp('b');
    verify(() => repo.reorder('t', ['a', 'b', 'pending'])).called(1);
    clearInteractions(repo);
    await cubit.moveUp('a');
    await cubit.moveDown('b');
    verifyNoMoreInteractions(repo);
  });
  test(
    'C-2: rename preserves the existing subtopic and reloads quota',
    () async {
      await cubit.load('t');
      await cubit.rename('a', ' Changed ');
      verify(() => repo.update('a', 'Changed', 's')).called(1);
      verify(repo.quota).called(2);
    },
  );
  test('C-2: addYoutube parses input and reloads list and quota', () async {
    await cubit.load('t');
    await cubit.addYoutube(
      title: ' New ',
      input: 'https://youtu.be/dQw4w9WgXcQ',
      durationS: 30,
    );
    verify(() => repo.addYoutube('t', 'New', 'dQw4w9WgXcQ', 30)).called(1);
    verify(() => repo.list('t')).called(2);
    verify(repo.quota).called(2);
  });
  test('C-2: invalid input never writes', () async {
    await cubit.load('t');
    await cubit.addYoutube(title: 'Title', input: 'bad', durationS: 30);
    expect((cubit.state as TeacherVideosReady).error?.code, 'invalid_input');
    verifyNever(() => repo.addYoutube(any(), any(), any(), any()));
  });
  test('C-2: delete failure keeps list and emits error after busy', () async {
    await cubit.load('t');
    when(
      () => repo.delete('a'),
    ).thenAnswer((_) async => const Failure(AppError('forbidden')));
    final observed = expectLater(
      cubit.stream,
      emitsInOrder([
        isA<TeacherVideosReady>().having((s) => s.busy, 'busy', isTrue),
        isA<TeacherVideosReady>()
            .having((s) => s.data.videos, 'videos', _videos)
            .having((s) => s.error?.code, 'error', 'forbidden'),
      ]),
    );
    await cubit.delete('a');
    await observed;
    verify(() => repo.list('t')).called(1);
  });
  for (final action in ['add', 'rename', 'move', 'delete']) {
    test('C-2: $action failure preserves videos', () async {
      await cubit.load('t');
      const result = Failure<void>(AppError('network'));
      switch (action) {
        case 'add':
          when(
            () => repo.addYoutube(any(), any(), any(), any()),
          ).thenAnswer((_) async => result);
          await cubit.addYoutube(
            title: 'Title',
            input: 'dQw4w9WgXcQ',
            durationS: 30,
          );
        case 'rename':
          when(
            () => repo.update(any(), any(), any()),
          ).thenAnswer((_) async => result);
          await cubit.rename('a', 'Changed');
        case 'move':
          when(
            () => repo.reorder(any(), any()),
          ).thenAnswer((_) async => result);
          await cubit.moveDown('a');
        case 'delete':
          when(() => repo.delete(any())).thenAnswer((_) async => result);
          await cubit.delete('a');
      }
      final ready = cubit.state as TeacherVideosReady;
      expect(ready.data.videos, _videos);
      expect(ready.busy, isFalse);
      expect(ready.error?.code, 'network');
    });
  }
  test('C-2: successful delete reloads list and quota', () async {
    await cubit.load('t');
    await cubit.delete('pending');
    verify(() => repo.delete('pending')).called(1);
    verify(() => repo.list('t')).called(2);
    verify(repo.quota).called(2);
  });
  test('C-2: pending rows cannot be renamed', () async {
    await cubit.load('t');
    await cubit.rename('pending', 'Changed');
    verifyNever(() => repo.update(any(), any(), any()));
    expect((cubit.state as TeacherVideosReady).error?.code, 'invalid_input');
  });
  test('C-2: refresh failure preserves last complete data', () async {
    await cubit.load('t');
    when(
      repo.quota,
    ).thenAnswer((_) async => const Failure(AppError('network')));
    await cubit.delete('a');
    final ready = cubit.state as TeacherVideosReady;
    expect(ready.data.videos, _videos);
    expect(ready.error?.code, 'network');
  });
  test('C-2: late load result after close emits nothing', () async {
    final pending = Completer<Result<List<TeacherVideo>>>();
    when(() => repo.list('t')).thenAnswer((_) => pending.future);
    final loading = cubit.load('t');
    await cubit.close();
    pending.complete(const Success(_videos));
    await loading;
    verifyNever(repo.quota);
  });
  test('C-2: busy action blocks repeated writes and reload', () async {
    await cubit.load('t');
    final pending = Completer<Result<void>>();
    when(() => repo.delete('a')).thenAnswer((_) => pending.future);
    final deleting = cubit.delete('a');
    await cubit.delete('a');
    await cubit.load('other');
    verify(() => repo.delete('a')).called(1);
    verifyNever(() => repo.list('other'));
    pending.complete(const Success(null));
    await deleting;
  });
}
