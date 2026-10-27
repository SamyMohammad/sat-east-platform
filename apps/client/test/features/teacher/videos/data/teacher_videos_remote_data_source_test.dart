import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/core/supabase/edge_caller.dart';
import 'package:sat_east_client/core/supabase/rpc_caller.dart';
import 'package:sat_east_client/core/video/video_provider.dart';
import 'package:sat_east_client/features/teacher/videos/data/datasources/teacher_videos_remote_data_source.dart';
import 'package:sat_east_client/features/teacher/videos/domain/entities/teacher_video.dart';
import 'package:sat_east_client/features/teacher/videos/domain/entities/video_quota.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Map<String, Object?> _row() => {
  'asset_id': 'a',
  'title': 'Lesson',
  'subtopic_id': 's',
  'subtopic_title': 'Part one',
  'duration_s': 600,
  'size_mb': 12,
  'provider': 'r2_hls',
  'youtube_id': null,
  'ready': false,
  'sort': 1,
};

void main() {
  TeacherVideosRemoteDataSource source({RpcCaller? rpc, EdgeCaller? edge}) =>
      TeacherVideosRemoteDataSource(
        rpc: rpc ?? (_, _) async => {'ok': true},
        edge: edge ?? (_, _) async => {'ok': true},
      );
  test(
    'C-2: list maps every teacher video field including pending rows',
    () async {
      final result = await source(
        rpc: (fn, params) async {
          expect(fn, 'teacher_list_videos');
          expect(params, {'p_topic_id': 't'});
          return [_row()];
        },
      ).list('t');
      final video = (result as Success<List<TeacherVideo>>).value.single;
      expect(video.assetId, 'a');
      expect(video.title, 'Lesson');
      expect(video.subtopicId, 's');
      expect(video.subtopicTitle, 'Part one');
      expect(video.durationS, 600);
      expect(video.sizeMb, 12);
      expect(video.provider, VideoProvider.r2Hls);
      expect(video.youtubeId, isNull);
      expect(video.ready, isFalse);
      expect(video.sort, 1);
    },
  );
  test('C-2: YouTube list permits nullable size and subtopic', () async {
    final result = await source(
      rpc: (_, _) async => [
        _row()..addAll({
          'provider': 'youtube',
          'youtube_id': 'dQw4w9WgXcQ',
          'size_mb': null,
          'subtopic_id': null,
          'subtopic_title': null,
          'ready': true,
        }),
      ],
    ).list('t');
    final video = (result as Success<List<TeacherVideo>>).value.single;
    expect(video.provider, VideoProvider.youtube);
    expect(video.sizeMb, isNull);
    expect(video.subtopicId, isNull);
  });
  test('C-2: quota calls teacher_video_quota without parameters', () async {
    final result = await source(
      rpc: (fn, params) async {
        expect(fn, 'teacher_video_quota');
        expect(params, isEmpty);
        return {'used_mb': 3277, 'cap_mb': 9216};
      },
    ).quota();
    expect((result as Success<VideoQuota>).value.label, '3.2 of 9 GB used');
  });
  test('C-2: add, update and reorder send exact RPC contracts', () async {
    final calls = <(String, Map<String, Object?>)>[];
    final remote = source(
      rpc: (fn, params) async {
        calls.add((fn, params));
        return {'ok': true, 'asset_id': 'new'};
      },
    );
    expect(
      await remote.addYoutube('t', 'Title', 'dQw4w9WgXcQ', 600),
      isA<Success<void>>(),
    );
    expect(await remote.update('a', 'Changed', 's'), isA<Success<void>>());
    expect(await remote.reorder('t', ['pending', 'a']), isA<Success<void>>());
    // Records compare maps by identity, so compare names and params apart.
    expect(calls.map((c) => c.$1), [
      'teacher_add_youtube_video',
      'teacher_update_video',
      'teacher_reorder_videos',
    ]);
    expect(calls.map((c) => c.$2), [
      {
        'p_topic_id': 't',
        'p_subtopic_id': null,
        'p_title': 'Title',
        'p_youtube_id': 'dQw4w9WgXcQ',
        'p_duration_s': 600,
      },
      {'p_asset_id': 'a', 'p_title': 'Changed', 'p_subtopic_id': 's'},
      {
        'p_topic_id': 't',
        'p_ids': ['pending', 'a'],
      },
    ]);
  });
  test('SEC-01: deletion calls only the Edge Function', () async {
    final remote = source(
      rpc: (_, _) async => fail('Delete used RPC'),
      edge: (path, body) async {
        expect(path, 'teacher/video-delete');
        expect(body, {'asset_id': 'a'});
        return {'ok': true};
      },
    );
    expect(await remote.delete('a'), isA<Success<void>>());
  });
  test('SEC-01: function failures preserve forbidden error', () async {
    final result = await source(
      edge: (_, _) async => throw const FunctionException(
        status: 403,
        details: {
          'error': {'code': 'forbidden'},
        },
      ),
    ).delete('a');
    expect((result as Failure<void>).error.code, 'forbidden');
  });
  test('C-2: RPC failures preserve quota_exceeded', () async {
    final result = await source(
      rpc: (_, _) async =>
          throw const PostgrestException(message: 'quota_exceeded'),
    ).addYoutube('t', 'Title', 'dQw4w9WgXcQ', 600);
    expect((result as Failure<void>).error.code, 'quota_exceeded');
  });
  for (final field in ['duration_s', 'ready', 'sort', 'provider']) {
    test('C-2: malformed video $field fails internally', () async {
      final result = await source(
        rpc: (_, _) async => [_row()..[field] = null],
      ).list('t');
      expect((result as Failure<List<TeacherVideo>>).error.code, 'internal');
    });
  }
  test('C-2: malformed quota fails internally', () async {
    final result = await source(rpc: (_, _) async => {'used_mb': 1}).quota();
    expect((result as Failure<VideoQuota>).error.code, 'internal');
  });
  test('C-2: malformed mutation acknowledgement fails internally', () async {
    final result = await source(edge: (_, _) async => null).delete('a');
    expect((result as Failure<void>).error.code, 'internal');
  });
}
