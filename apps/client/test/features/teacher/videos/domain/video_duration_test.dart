import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/features/teacher/videos/domain/video_duration.dart';

void main() {
  for (final (input, seconds) in [
    ('10:00', 600),
    ('0:30', 30),
    (' 120:59 ', 7259),
    ('35791394:07', 2147483647),
  ]) {
    test('C-2: parses duration $input', () {
      expect(parseVideoDuration(input), seconds);
    });
  }
  for (final input in [
    '0:00',
    '1:60',
    '10',
    '-1:30',
    '1:2:3',
    '1:5',
    '35791394:08',
    '999999999999999999999999:00',
  ]) {
    test('C-2: rejects duration $input', () {
      expect(parseVideoDuration(input), isNull);
    });
  }
}
