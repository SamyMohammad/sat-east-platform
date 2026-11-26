import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/observability/sentry_error_reporter.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

void main() {
  group('configureSentry', () {
    test('OPS-01 sets the release and samples 5% of traces', () {
      final options = SentryFlutterOptions();
      configureSentry(
        options,
        dsn: 'https://key@o1.ingest.sentry.io/1',
        environment: 'staging',
        release: 'abc123',
      );
      expect(options.release, 'abc123');
      expect(options.tracesSampleRate, 0.05);
      expect(options.environment, 'staging');
    });

    test('OPS-01 leaves the release unset when empty', () {
      final options = SentryFlutterOptions();
      final before = options.release;
      configureSentry(
        options,
        dsn: 'https://key@o1.ingest.sentry.io/1',
        environment: 'prod',
        release: '',
      );
      expect(options.release, before);
    });

    test('OPS-01 keeps tracing off without a DSN', () {
      final options = SentryFlutterOptions();
      configureSentry(options, dsn: '', environment: 'dev', release: 'abc');
      expect(options.tracesSampleRate, 0);
    });
  });
}
