import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/core/supabase/edge_caller.dart';
import 'package:sat_east_client/core/supabase/rpc_caller.dart';
import 'package:sat_east_client/features/teacher/videos/data/datasources/video_upload_remote_data_source.dart';
import 'package:sat_east_client/features/teacher/videos/data/repositories/video_upload_repository_impl.dart';
import 'package:sat_east_client/features/teacher/videos/domain/entities/video_upload.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  VideoUploadRemoteDataSource source({
    RpcCaller? rpc,
    EdgeCaller? edge,
    VideoSettingsRows? settings,
  }) => VideoUploadRemoteDataSource(
    rpc: rpc ?? (_, _) async => {'ok': true},
    edge: edge ?? (_, _) async => {'ok': true},
    readSettings: settings ?? () async => <Object?>[],
  );

  String code<T>(Result<T> r) => (r as Failure<T>).error.code;

  group('limits', () {
    test('VID-01: reads both video upload settings', () async {
      final result = await source(
        settings: () async => [
          {'key': 'video_upload_max_source_mb', 'value': 500},
          {'key': 'video_upload_max_duration_s', 'value': 900},
        ],
      ).limits();
      expect(
        (result as Success<VideoUploadLimits>).value,
        const VideoUploadLimits(maxSourceMb: 500, maxDurationS: 900),
      );
    });

    test('VID-01: missing keys become null limits', () async {
      final result = await source().limits();
      expect(
        (result as Success<VideoUploadLimits>).value,
        const VideoUploadLimits(),
      );
    });

    test('VID-01: a malformed value fails instead of being ignored', () async {
      final result = await source(
        settings: () async => [
          {'key': 'video_upload_max_source_mb', 'value': 'big'},
        ],
      ).limits();
      expect(code(result), ErrorCodes.internal);
    });

    test('VID-01: a read failure is mapped', () async {
      final result = await source(
        settings: () async => throw const PostgrestException(message: 'x'),
      ).limits();
      expect(code(result), ErrorCodes.internal);
    });
  });

  group('createAsset', () {
    test(
      'VID-01: calls teacher_create_video_asset and returns the id',
      () async {
        final result =
            await source(
              rpc: (fn, params) async {
                expect(fn, 'teacher_create_video_asset');
                expect(params, {
                  'p_topic_id': 't',
                  'p_subtopic_id': null,
                  'p_title': 'Title',
                  'p_duration_s': 61,
                  'p_size_mb': 12,
                });
                return {'ok': true, 'asset_id': 'a1'};
              },
            ).createAsset(
              topicId: 't',
              subtopicId: null,
              title: 'Title',
              durationS: 61,
              sizeMb: 12,
            );
        expect((result as Success<String>).value, 'a1');
      },
    );

    test('VID-01: quota_exceeded result becomes a Failure', () async {
      final result =
          await source(
            rpc: (_, _) async => {
              'ok': false,
              'error': 'quota_exceeded',
              'used_mb': 9000,
              'cap_mb': 9216,
            },
          ).createAsset(
            topicId: 't',
            subtopicId: null,
            title: 'T',
            durationS: 1,
            sizeMb: 1,
          );
      expect(code(result), ErrorCodes.quotaExceeded);
    });

    test('VID-01: a reply without asset_id is internal', () async {
      final result = await source(rpc: (_, _) async => {'ok': true})
          .createAsset(
            topicId: 't',
            subtopicId: null,
            title: 'T',
            durationS: 1,
            sizeMb: 1,
          );
      expect(code(result), ErrorCodes.internal);
    });

    test('VID-01: RPC error codes pass through', () async {
      final result =
          await source(
            rpc: (_, _) async =>
                throw const PostgrestException(message: 'forbidden'),
          ).createAsset(
            topicId: 't',
            subtopicId: null,
            title: 'T',
            durationS: 1,
            sizeMb: 1,
          );
      expect(code(result), ErrorCodes.forbidden);
    });
  });

  group('uploadUrls', () {
    test(
      'VID-01: posts to teacher/video-upload-urls and returns the map',
      () async {
        final result = await source(
          edge: (path, body) async {
            expect(path, 'teacher/video-upload-urls');
            expect(body, {
              'asset_id': 'a1',
              'files': ['master.m3u8', '540p_000.ts'],
            });
            return {
              'urls': {
                'master.m3u8': 'https://r2.example/a?sig=1',
                '540p_000.ts': 'https://r2.example/b?sig=2',
              },
              'expires_in': 900,
            };
          },
        ).uploadUrls('a1', ['master.m3u8', '540p_000.ts']);
        expect((result as Success<Map<String, String>>).value, {
          'master.m3u8': 'https://r2.example/a?sig=1',
          '540p_000.ts': 'https://r2.example/b?sig=2',
        });
      },
    );

    test('VID-01: a missing URL for a requested file is internal', () async {
      final result = await source(
        edge: (_, _) async => {
          'urls': {'master.m3u8': 'https://r2.example/a'},
        },
      ).uploadUrls('a1', ['master.m3u8', '540p_000.ts']);
      expect(code(result), ErrorCodes.internal);
    });

    test('VID-01: non-https or credentialed URLs are refused', () async {
      for (final url in [
        'http://r2.example/a',
        'https://user:pw@r2.example/a',
        'not a url',
      ]) {
        final result = await source(
          edge: (_, _) async => {
            'urls': {'master.m3u8': url},
          },
        ).uploadUrls('a1', ['master.m3u8']);
        expect(code(result), ErrorCodes.internal, reason: url);
      }
    });

    test('VID-01: structured Edge errors keep their code', () async {
      final result = await source(
        edge: (_, _) async => throw const FunctionException(
          status: 403,
          details: {
            'error': {'code': 'forbidden'},
          },
        ),
      ).uploadUrls('a1', ['master.m3u8']);
      expect(code(result), ErrorCodes.forbidden);
    });
  });

  group('confirm', () {
    test(
      'VID-01: calls teacher_confirm_video_asset with the hex key',
      () async {
        final result = await source(
          rpc: (fn, params) async {
            expect(fn, 'teacher_confirm_video_asset');
            expect(params, {'p_asset_id': 'a1', 'p_key_hex': 'ab' * 16});
            return {'ok': true};
          },
        ).confirm('a1', 'ab' * 16);
        expect(result, isA<Success<void>>());
      },
    );

    test('VID-01: a non-ok reply is internal', () async {
      final result = await source(
        rpc: (_, _) async => {'ok': false},
      ).confirm('a1', 'ab' * 16);
      expect(code(result), ErrorCodes.internal);
    });
  });

  test('VID-01: repository delegates every call', () async {
    final repo = VideoUploadRepositoryImpl(
      source(
        rpc: (fn, _) async => fn == 'teacher_create_video_asset'
            ? {'ok': true, 'asset_id': 'a1'}
            : {'ok': true},
        edge: (_, _) async => {
          'urls': {'master.m3u8': 'https://r2.example/a'},
        },
      ),
    );
    expect(
      (await repo.createAsset(
                topicId: 't',
                subtopicId: null,
                title: 'T',
                durationS: 1,
                sizeMb: 1,
              )
              as Success<String>)
          .value,
      'a1',
    );
    expect(
      await repo.uploadUrls('a1', ['master.m3u8']),
      isA<Success<Map<String, String>>>(),
    );
    expect(await repo.confirm('a1', 'ab' * 16), isA<Success<void>>());
    expect(await repo.limits(), isA<Success<VideoUploadLimits>>());
  });
}
