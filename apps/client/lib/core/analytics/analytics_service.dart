import 'package:sat_east_client/core/analytics/analytics_event.dart';

/// Product analytics (ADR-008). Features depend on this, never on PostHog.
abstract interface class AnalyticsService {
  Future<void> track(AnalyticsEvent event);

  /// [userId] is the Supabase user id — never an email or name.
  Future<void> identify(String userId);

  /// Call on sign-out.
  Future<void> reset();
}

/// Used when `POSTHOG_KEY` is empty (dev, CI, tests).
final class NoopAnalyticsService implements AnalyticsService {
  const NoopAnalyticsService();

  @override
  Future<void> track(AnalyticsEvent event) async {}

  @override
  Future<void> identify(String userId) async {}

  @override
  Future<void> reset() async {}
}
