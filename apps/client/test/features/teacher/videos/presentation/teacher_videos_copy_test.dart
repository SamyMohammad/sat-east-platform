import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/features/teacher/videos/presentation/teacher_videos_copy.dart';

void main() {
  test('VID-01: video_engine_load_failed maps to its own copy', () {
    final copy = TeacherVideosCopy.uploadError(
      ErrorCodes.videoEngineLoadFailed,
    );
    expect(
      copy,
      "Couldn't load the video tools. Check your connection and try again.",
    );
    expect(copy, isNot(TeacherVideosCopy.uploadError('unknown_code')));
  });

  test('VID-01: copy never echoes the raw error code', () {
    expect(
      TeacherVideosCopy.uploadError(ErrorCodes.videoEngineLoadFailed),
      isNot(contains('video_engine_load_failed')),
    );
  });
}
