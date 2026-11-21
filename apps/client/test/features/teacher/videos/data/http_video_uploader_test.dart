import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/teacher/videos/data/services/http_video_uploader.dart';
import 'package:sat_east_client/features/teacher/videos/domain/entities/video_upload.dart';

HlsFile _file(String name, [int length = 3]) =>
    HlsFile(name: name, bytes: Uint8List.fromList(List.filled(length, 7)));

Map<String, String> _urls(Iterable<String> names) => {
  for (final n in names) n: 'https://r2.example/videos/a/$n?X-Amz-Signature=s',
};

void main() {
  String code(Result<void> r) => (r as Failure<void>).error.code;

  test(
    'VID-01: PUTs every file with its content type and no redirects',
    () async {
      final seen = <http.Request>[];
      final bodies = <String, List<int>>{};
      final client = MockClient((request) async {
        seen.add(request);
        bodies[request.url.pathSegments.last] = request.bodyBytes;
        return http.Response('', 200);
      });
      final files = [_file('master.m3u8'), _file('540p_000.ts', 5)];
      final result = await HttpVideoUploader(
        client,
      ).upload(files, _urls(files.map((f) => f.name)));
      expect(result, isA<Success<void>>());
      expect(seen.map((r) => r.method), everyElement('PUT'));
      expect(seen.every((r) => !r.followRedirects), isTrue);
      expect(
        {
          for (final r in seen)
            r.url.pathSegments.last: r.headers['content-type'],
        },
        {
          'master.m3u8': 'application/vnd.apple.mpegurl',
          '540p_000.ts': 'video/mp2t',
        },
      );
      expect(bodies['540p_000.ts'], List.filled(5, 7));
      expect(seen.first.url.queryParameters['X-Amz-Signature'], 's');
    },
  );

  test('VID-01: at most four PUTs are in flight', () async {
    var inFlight = 0;
    var peak = 0;
    final gates = <Completer<void>>[];
    final client = MockClient((request) async {
      inFlight++;
      peak = peak < inFlight ? inFlight : peak;
      final gate = Completer<void>();
      gates.add(gate);
      await gate.future;
      inFlight--;
      return http.Response('', 200);
    });
    final files = [for (var i = 0; i < 10; i++) _file('s$i.ts')];
    final future = HttpVideoUploader(
      client,
    ).upload(files, _urls(files.map((f) => f.name)));
    await pumpEventQueue();
    expect(gates.length, 4);
    while (gates.any((g) => !g.isCompleted) || inFlight > 0) {
      for (final g in gates.where((g) => !g.isCompleted)) {
        g.complete();
      }
      await pumpEventQueue();
    }
    expect(await future, isA<Success<void>>());
    expect(peak, 4);
    expect(gates.length, 10);
  });

  test('VID-01: progress counts finished files', () async {
    final client = MockClient((_) async => http.Response('', 200));
    final files = [_file('a.ts'), _file('b.ts'), _file('c.ts')];
    final done = <int>[];
    await HttpVideoUploader(client).upload(
      files,
      _urls(files.map((f) => f.name)),
      onProgress: (d, total) {
        expect(total, 3);
        done.add(d);
      },
    );
    expect(done, [1, 2, 3]);
  });

  test(
    'VID-01: an HTTP error fails with status only and stops new PUTs',
    () async {
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        return http.Response(
          '<Error><Code>SignatureDoesNotMatch</Code></Error>',
          403,
        );
      });
      final files = [for (var i = 0; i < 20; i++) _file('s$i.ts')];
      final result = await HttpVideoUploader(
        client,
      ).upload(files, _urls(files.map((f) => f.name)));
      expect(code(result), ErrorCodes.videoUploadFailed);
      final error = (result as Failure<void>).error;
      expect(error.message, 'HTTP 403');
      expect(error.message, isNot(contains('Signature')));
      expect(calls, lessThan(20));
    },
  );

  test('VID-01: transport failure maps to network', () async {
    final client = MockClient((_) async => throw http.ClientException('boom'));
    final result = await HttpVideoUploader(
      client,
    ).upload([_file('a.ts')], _urls(['a.ts']));
    expect(code(result), ErrorCodes.network);
  });

  test(
    'VID-01: a missing or non-https URL fails without any request',
    () async {
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        return http.Response('', 200);
      });
      final uploader = HttpVideoUploader(client);
      expect(
        code(await uploader.upload([_file('a.ts')], const <String, String>{})),
        ErrorCodes.videoUploadFailed,
      );
      expect(
        code(await uploader.upload([_file('a.ts')], {'a.ts': 'http://x/a'})),
        ErrorCodes.videoUploadFailed,
      );
      expect(calls, 0);
    },
  );

  test(
    'VID-01: cancel stops new PUTs and reports cancelled',
    () async {
      final started = <String>[];
      final gates = <Completer<void>>[];
      late HttpVideoUploader uploader;
      final client = MockClient((request) async {
        started.add(request.url.pathSegments.last);
        final gate = Completer<void>();
        gates.add(gate);
        await gate.future;
        return http.Response('', 200);
      });
      uploader = HttpVideoUploader(client);
      final files = [for (var i = 0; i < 10; i++) _file('s$i.ts')];
      final future = uploader.upload(files, _urls(files.map((f) => f.name)));
      await pumpEventQueue();
      uploader.cancel();
      for (final g in gates) {
        g.complete();
      }
      expect(code(await future), ErrorCodes.cancelled);
      expect(started.length, 4);
    },
  );
}
