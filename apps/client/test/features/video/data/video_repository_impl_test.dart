import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/video/data/datasources/video_remote_data_source.dart';
import 'package:sat_east_client/features/video/data/repositories/video_repository_impl.dart';
import 'package:sat_east_client/features/video/domain/entities/video_playback.dart';
import 'package:sat_east_client/features/video/domain/entities/video_settings.dart';
import 'package:sat_east_client/features/video/domain/entities/watched_span.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  for (final fails in [false, true]) {
    test(
      'LRN-02: repository forwards playback, progress, settings '
      'failure=$fails',
      () async {
        final repo = VideoRepositoryImpl(
          VideoRemoteDataSource(
            edge: (path, body) async {
              expect(path, 'video-otp');
              expect(body, {'asset_id': 'v'});
              if (fails) throw const FunctionException(status: 401);
              return {
                'provider': 'youtube',
                'youtube_id': 'dQw4w9WgXcQ',
                'resume_s': 0,
              };
            },
            rpc: (fn, params) async {
              expect(params['p_asset_id'], 'v');
              expect(params['p_to_s'], 14);
              if (fails) throw const PostgrestException(message: 'forbidden');
              return {'pct': 40, 'done': false};
            },
            readSettings: () async => fails
                ? []
                : [
                    {'key': 'video_progress_interval_s', 'value': 15},
                    {'key': 'video_watermark_move_s', 'value': 7},
                  ],
          ),
        );
        final playback = await repo.requestPlayback('v');
        final progress = await repo.saveProgress(
          'v',
          const WatchedSpan(fromS: 0, toS: 14),
          14,
        );
        final settings = await repo.loadSettings();
        if (fails) {
          expect(
            (playback as Failure<VideoPlayback>).error.code,
            'not_authenticated',
          );
          expect(
            (progress as Failure<({int pct, bool done})>).error.code,
            'forbidden',
          );
          expect((settings as Failure<VideoSettings>).error.code, 'internal');
        } else {
          expect(
            (playback as Success<VideoPlayback>).value,
            isA<YoutubePlayback>(),
          );
          expect((progress as Success<({int pct, bool done})>).value, (
            pct: 40,
            done: false,
          ));
          expect((settings as Success<VideoSettings>).value.watermarkMoveS, 7);
        }
      },
    );
  }
}
