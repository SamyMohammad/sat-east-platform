/// Build-time configuration, injected with
/// `--dart-define-from-file=env/<flavor>.json`.
enum Flavor { dev, staging, prod }

abstract final class Env {
  static const String _flavor = String.fromEnvironment(
    'FLAVOR',
    defaultValue: 'dev',
  );

  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');

  static const String supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );

  /// Purchase UI is web-only (ADR-006); the flag lets the web build opt in.
  static const bool enablePurchase = bool.fromEnvironment('ENABLE_PURCHASE');

  /// Public client keys (docs/05 §6, ADR-008). Empty → the service is off.
  static const String sentryDsn = String.fromEnvironment('SENTRY_DSN');

  static const String posthogKey = String.fromEnvironment('POSTHOG_KEY');

  static const String posthogHost = String.fromEnvironment(
    'POSTHOG_HOST',
    defaultValue: 'https://eu.i.posthog.com',
  );

  static Flavor get flavor => Flavor.values.byName(_flavor);

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty &&
      supabasePublishableKey.isNotEmpty &&
      !supabasePublishableKey.startsWith('<');
}
