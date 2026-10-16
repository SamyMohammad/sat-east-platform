import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/features/auth/data/datasources/device_info.dart';

void main() {
  group('P1-2: labelFromUserAgent', () {
    const cases = <String, String>{
      'Chrome on Windows':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
      'Edge on Windows':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36 Edg/126.0.0.0',
      'Firefox on Linux':
          'Mozilla/5.0 (X11; Linux x86_64; rv:127.0) Gecko/20100101 Firefox/127.0',
      'Safari on macOS':
          'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Safari/605.1.15',
      'Chrome on Android':
          'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Mobile Safari/537.36',
      'Safari on iOS':
          'Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1',
    };
    for (final entry in cases.entries) {
      test('P1-2: labels ${entry.key}', () {
        expect(labelFromUserAgent(entry.value), entry.key);
      });
    }

    test('P1-2: falls back to Web browser for unknown agent', () {
      expect(labelFromUserAgent('SomeBot/1.0'), 'Web browser');
    });

    test('P1-2: falls back to Web browser for empty agent', () {
      expect(labelFromUserAgent(''), 'Web browser');
    });
  });

  group('P1-2: truncateLabel', () {
    test('P1-2: keeps a label of 80 chars unchanged', () {
      final s = 'a' * 80;
      expect(truncateLabel(s), s);
    });

    test('P1-2: cuts a longer label to 80 chars', () {
      expect(truncateLabel('a' * 200).length, 80);
    });

    test('P1-2: keeps a short label unchanged', () {
      expect(truncateLabel('Chrome on Windows'), 'Chrome on Windows');
    });
  });
}
