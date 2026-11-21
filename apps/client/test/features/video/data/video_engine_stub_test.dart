import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/core/video/video_provider.dart';
import 'package:sat_east_client/features/video/data/services/video_engine_factory.dart';
import 'package:sat_east_client/features/video/domain/entities/video_playback.dart';

void main() {
  for (final provider in VideoProvider.values) {
    test(
      'LRN-02: non-web $provider is unsupported with empty streams',
      () async {
        final engine = createVideoEngine(provider);
        final result = await engine.attach(
          HlsPlayback(
            hlsUrl: 'https://cdn.test/v.m3u8',
            expiresAt: DateTime.utc(2030),
            watermarkName: 'Sara Ali',
            watermarkShortId: '3FA2C1',
            resumeS: 0,
          ),
        );
        expect((result as Failure<void>).error.code, ErrorCodes.unsupported);
        await expectLater(engine.position, emitsDone);
        await expectLater(engine.status, emitsDone);
        await expectLater(engine.fatalErrors, emitsDone);
        expect(engine.durationS, isNull);
        engine
          ..play()
          ..pause()
          ..seek(0)
          ..setRate(1);
        await engine.requestFullscreen();
        await engine.exitFullscreen();
        await engine.dispose();
      },
    );
  }
}
