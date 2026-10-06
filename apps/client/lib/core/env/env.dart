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

  static Flavor get flavor => Flavor.values.byName(_flavor);

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty &&
      supabasePublishableKey.isNotEmpty &&
      !supabasePublishableKey.startsWith('<');
}
