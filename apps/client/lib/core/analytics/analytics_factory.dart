import 'package:sat_east_client/core/analytics/analytics_service.dart';
import 'package:sat_east_client/core/analytics/posthog_analytics_service.dart';
import 'package:sat_east_client/core/observability/error_reporter.dart';

typedef PosthogStarter =
    Future<AnalyticsService> Function({
      required String projectToken,
      required String host,
    });

/// PostHog when a key is set, otherwise a no-op. A PostHog failure is
/// reported and never blocks app start.
Future<AnalyticsService> createAnalytics({
  required String projectToken,
  required String host,
  required ErrorReporter reporter,
  PosthogStarter start = PosthogAnalyticsService.start,
}) async {
  if (projectToken.isEmpty) return const NoopAnalyticsService();
  try {
    return await start(projectToken: projectToken, host: host);
  } on Object catch (e, st) {
    await reporter.captureError(e, st, hint: 'analytics start failed');
    return const NoopAnalyticsService();
  }
}
