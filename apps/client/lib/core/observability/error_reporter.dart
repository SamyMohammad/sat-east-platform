/// Crash and error reporting (ADR-008). Features and data sources depend on
/// this, never on Sentry.
abstract interface class ErrorReporter {
  Future<void> captureError(
    Object error,
    StackTrace? stackTrace, {
    String? hint,
  });

  /// [userId] is the Supabase user id — never an email or name.
  Future<void> setUser(String userId);

  /// Call on sign-out.
  Future<void> clearUser();
}

/// Used when `SENTRY_DSN` is empty (dev, CI, tests).
final class NoopErrorReporter implements ErrorReporter {
  const NoopErrorReporter();

  @override
  Future<void> captureError(
    Object error,
    StackTrace? stackTrace, {
    String? hint,
  }) async {}

  @override
  Future<void> setUser(String userId) async {}

  @override
  Future<void> clearUser() async {}
}
