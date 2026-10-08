/// Non-web builds: PostHog's native SDK is set up through `Posthog().setup`.
Future<void> loadPosthogWeb({
  required String projectToken,
  required String host,
}) async {}
