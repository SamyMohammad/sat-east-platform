import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/features/teacher/videos/domain/youtube_id.dart';

void main() {
  for (final input in [
    'dQw4w9WgXcQ',
    ' https://youtu.be/dQw4w9WgXcQ ',
    'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
    'https://youtube.com/embed/dQw4w9WgXcQ',
    'https://youtube.com/shorts/dQw4w9WgXcQ',
    'https://youtube.com/watch?v=dQw4w9WgXcQ&t=30s',
  ]) {
    test('C-2: accepts YouTube input $input', () {
      expect(parseYoutubeId(input), 'dQw4w9WgXcQ');
    });
  }
  for (final input in [
    '',
    'abc',
    'https://example.test/dQw4w9WgXcQ',
    'https://youtube.com.evil.test/watch?v=dQw4w9WgXcQ',
    'https://youtube.com@evil.test/watch?v=dQw4w9WgXcQ',
    'https://youtu.be/dQw4w9WgXcQ/extra',
    'ftp://youtube.com/watch?v=dQw4w9WgXcQ',
  ]) {
    test('C-2: rejects invalid YouTube input $input', () {
      expect(parseYoutubeId(input), isNull);
    });
  }
}
