import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sat_east_client/core/analytics/analytics_event.dart';
import 'package:sat_east_client/core/analytics/analytics_factory.dart';
import 'package:sat_east_client/core/analytics/analytics_service.dart';
import 'package:sat_east_client/core/analytics/posthog_analytics_service.dart';
import 'package:sat_east_client/core/observability/error_reporter.dart';

class _MockPosthogClient extends Mock implements PosthogClient {}

class _MockReporter extends Mock implements ErrorReporter {}

void main() {
  group('PosthogAnalyticsService', () {
    late _MockPosthogClient client;
    late PosthogAnalyticsService service;

    setUp(() {
      client = _MockPosthogClient();
      when(() => client.capture(any(), any())).thenAnswer((_) async {});
      when(() => client.identify(any())).thenAnswer((_) async {});
      when(() => client.reset()).thenAnswer((_) async {});
      service = PosthogAnalyticsService(client);
    });

    test('F-5 track sends the event name and properties', () async {
      await service.track(
        const StepCompleted(topicId: 't1', step: TopicStep.quiz),
      );
      verify(
        () => client.capture('step_complete', {
          'topic_id': 't1',
          'step': 'quiz',
        }),
      ).called(1);
    });

    test('F-5 identify and reset pass through', () async {
      await service.identify('user-uuid');
      await service.reset();
      verify(() => client.identify('user-uuid')).called(1);
      verify(() => client.reset()).called(1);
    });
  });

  group('createAnalytics', () {
    late _MockReporter reporter;

    setUp(() {
      reporter = _MockReporter();
      when(
        () => reporter.captureError(any(), any(), hint: any(named: 'hint')),
      ).thenAnswer((_) async {});
    });

    test('F-5 no key → no-op, PostHog never started', () async {
      var started = false;
      final analytics = await createAnalytics(
        projectToken: '',
        host: 'https://eu.i.posthog.com',
        reporter: reporter,
        start: ({required projectToken, required host}) async {
          started = true;
          return const NoopAnalyticsService();
        },
      );
      expect(analytics, isA<NoopAnalyticsService>());
      expect(started, isFalse);
    });

    test('F-5 key set → the started service is used', () async {
      final posthog = PosthogAnalyticsService(_MockPosthogClient());
      final analytics = await createAnalytics(
        projectToken: 'phc_test',
        host: 'https://eu.i.posthog.com',
        reporter: reporter,
        start: ({required projectToken, required host}) async => posthog,
      );
      expect(analytics, same(posthog));
    });

    test('F-5 start failure is reported and falls back to no-op', () async {
      final analytics = await createAnalytics(
        projectToken: 'phc_test',
        host: 'https://eu.i.posthog.com',
        reporter: reporter,
        start: ({required projectToken, required host}) =>
            Future.error(StateError('posthog-js failed to load')),
      );
      expect(analytics, isA<NoopAnalyticsService>());
      verify(
        () => reporter.captureError(
          any(that: isA<StateError>()),
          any(),
          hint: 'analytics start failed',
        ),
      ).called(1);
    });
  });
}
