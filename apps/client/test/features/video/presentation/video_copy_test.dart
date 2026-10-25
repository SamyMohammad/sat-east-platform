import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/features/video/presentation/video_copy.dart';

void main() {
  for (final (code, copy) in [
    ('video_needed', "This video isn't open yet."),
    ('topic_locked', "This video isn't open yet."),
    ('not_enrolled', 'Your access to this course has ended.'),
    ('access_expired', 'Your access to this course has ended.'),
    ('device_revoked', 'This device was signed out. Sign in again.'),
    ('rate_limited', 'Too many tries. Wait a minute and retry.'),
    ('unsupported', 'Video plays in the web app for now.'),
    ('internal', "Couldn't load the video. Try again."),
  ]) {
    test('LRN-02: $code maps to safe English copy', () {
      expect(VideoCopy.error(code), copy);
    });
  }
}
