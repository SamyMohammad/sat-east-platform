import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/features/teacher/videos/data/services/ffmpeg_core_integrity.dart';

void main() {
  final digest = Uint8List.fromList([0x00, 0x0f, 0xa5, 0xff]);

  group('VID-01: ffmpeg core integrity', () {
    test('hexOf pads each byte to two lowercase hex digits', () {
      expect(hexOf(digest), '000fa5ff');
    });

    test('digestMatches is true for the same digest', () {
      expect(digestMatches(digest, '000fa5ff'), isTrue);
    });

    test('digestMatches ignores the case of the expected hash', () {
      expect(digestMatches(digest, '000FA5FF'), isTrue);
    });

    test('digestMatches is false for a different digest', () {
      expect(digestMatches(digest, '000fa5fe'), isFalse);
    });

    test('digestMatches is false for a different length', () {
      expect(digestMatches(digest, '000fa5'), isFalse);
      expect(digestMatches(digest, ''), isFalse);
    });

    test('pinned hashes are 64 lowercase hex characters', () {
      for (final hash in [ffmpegCoreJsSha256, ffmpegCoreWasmSha256]) {
        expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(hash), isTrue);
      }
    });

    test('core is pinned to an exact version on jsDelivr', () {
      for (final url in [ffmpegCoreJsUrl, ffmpegCoreWasmUrl]) {
        expect(
          url,
          startsWith('https://cdn.jsdelivr.net/npm/@ffmpeg/core@0.12.10/'),
        );
      }
    });
  });
}
