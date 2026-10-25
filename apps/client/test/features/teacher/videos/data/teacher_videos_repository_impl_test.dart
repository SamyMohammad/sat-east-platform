import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/teacher/videos/data/datasources/teacher_videos_remote_data_source.dart';
import 'package:sat_east_client/features/teacher/videos/data/repositories/teacher_videos_repository_impl.dart';
import 'package:sat_east_client/features/teacher/videos/domain/entities/teacher_video.dart';
import 'package:sat_east_client/features/teacher/videos/domain/entities/video_quota.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('C-2: repository delegates listing and quota', () async {
    final repo = TeacherVideosRepositoryImpl(
      TeacherVideosRemoteDataSource(
        rpc: (fn, params) async {
          if (fn == 'teacher_list_videos') {
            expect(params, {'p_topic_id': 't'});
            return <Object?>[];
          }
          return {'used_mb': 3277, 'cap_mb': 9216};
        },
        edge: (_, _) async => {'ok': true},
      ),
    );
    expect(
      (await repo.list('t') as Success<List<TeacherVideo>>).value,
      isEmpty,
    );
    expect((await repo.quota() as Success<VideoQuota>).value.usedMb, 3277);
  });
  test('SEC-01: repository preserves Edge delete failure', () async {
    final repo = TeacherVideosRepositoryImpl(
      TeacherVideosRemoteDataSource(
        rpc: (_, _) async => null,
        edge: (_, _) async => throw const FunctionException(
          status: 403,
          details: {
            'error': {'code': 'forbidden'},
          },
        ),
      ),
    );
    expect((await repo.delete('a') as Failure<void>).error.code, 'forbidden');
  });
}
