import 'package:flutter/foundation.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:sat_east_client/core/analytics/analytics_event.dart';
import 'package:sat_east_client/core/analytics/analytics_service.dart';
import 'package:sat_east_client/core/analytics/posthog_web_loader.dart';

/// The calls we use from the PostHog SDK; a seam for tests.
abstract interface class PosthogClient {
  Future<void> capture(String eventName, Map<String, Object> properties);

  Future<void> identify(String userId);

  Future<void> reset();
}

final class SdkPosthogClient implements PosthogClient {
  const SdkPosthogClient();

  @override
  Future<void> capture(String eventName, Map<String, Object> properties) =>
      Posthog().capture(eventName: eventName, properties: properties);

  @override
  Future<void> identify(String userId) => Posthog().identify(userId: userId);

  @override
  Future<void> reset() => Posthog().reset();
}

final class PosthogAnalyticsService implements AnalyticsService {
  PosthogAnalyticsService(this._client);

  final PosthogClient _client;

  /// Starts PostHog with privacy-first settings (ADR-008): person profiles
  /// only after identify, no autocapture, no session replay, no surveys.
  static Future<PosthogAnalyticsService> start({
    required String projectToken,
    required String host,
  }) async {
    if (kIsWeb) {
      // posthog_flutter cannot set itself up on web; it drives window.posthog.
      await loadPosthogWeb(projectToken: projectToken, host: host);
    } else {
      final config = PostHogConfig(projectToken)
        ..host = host
        ..personProfiles = PostHogPersonProfiles.identifiedOnly
        ..captureApplicationLifecycleEvents = false
        ..sessionReplay = false
        ..surveys = false;
      await Posthog().setup(config);
    }
    return PosthogAnalyticsService(const SdkPosthogClient());
  }

  @override
  Future<void> track(AnalyticsEvent event) =>
      _client.capture(event.name, event.properties);

  @override
  Future<void> identify(String userId) => _client.identify(userId);

  @override
  Future<void> reset() => _client.reset();
}
