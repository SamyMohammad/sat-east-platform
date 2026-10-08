import 'package:sat_east_client/core/observability/error_reporter.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

final class SentryErrorReporter implements ErrorReporter {
  const SentryErrorReporter();

  @override
  Future<void> captureError(
    Object error,
    StackTrace? stackTrace, {
    String? hint,
  }) async {
    await Sentry.captureException(
      error,
      stackTrace: stackTrace,
      hint: hint == null ? null : Hint.withMap({'hint': hint}),
    );
  }

  @override
  Future<void> setUser(String userId) async {
    await Sentry.configureScope(
      (scope) => scope.setUser(SentryUser(id: userId)),
    );
  }

  @override
  Future<void> clearUser() async {
    await Sentry.configureScope((scope) => scope.setUser(null));
  }
}

/// Sentry options for this app (ADR-008, CLAUDE.md A.6).
void configureSentry(
  SentryFlutterOptions options, {
  required String dsn,
  required String environment,
}) {
  options
    ..dsn = dsn
    ..environment = environment
    ..sendDefaultPii = false
    // Errors only for now; performance tracing is a later decision.
    ..tracesSampleRate = 0
    ..beforeSend = ((event, hint) => scrubEvent(event))
    ..beforeBreadcrumb = ((crumb, hint) => scrubBreadcrumb(crumb));
}

/// Long path segments are tokens (signed video/PDF URLs put them in the path).
final _tokenSegment = RegExp(r'^[A-Za-z0-9._~-]{32,}$');

/// Keeps scheme, host and path shape; drops the query, fragment and tokens.
String redactUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null || !uri.hasScheme) return '[url]';
  final segments = uri.pathSegments
      .map((s) => _tokenSegment.hasMatch(s) ? ':token' : s)
      .toList();
  return uri
      .replace(pathSegments: segments, query: '', fragment: '')
      .toString()
      .replaceAll(RegExp(r'[?#]+$'), '');
}

/// Removes PII and secrets before an event leaves the device: user = id only,
/// no request body, cookies or headers (they can carry the JWT), URLs redacted.
SentryEvent scrubEvent(SentryEvent event) {
  final userId = event.user?.id;
  event.user = userId == null ? null : SentryUser(id: userId);
  final request = event.request;
  if (request != null) {
    event.request = SentryRequest(
      method: request.method,
      url: request.url == null ? null : redactUrl(request.url!),
    );
  }
  event.breadcrumbs = event.breadcrumbs?.map(scrubBreadcrumb).nonNulls.toList();
  return event;
}

Breadcrumb? scrubBreadcrumb(Breadcrumb? crumb) {
  if (crumb == null) return null;
  final data = crumb.data;
  if (data == null) return crumb;
  final cleaned = <String, dynamic>{
    for (final MapEntry(:key, :value) in data.entries)
      if (key == 'url' && value is String)
        key: redactUrl(value)
      else if (key != 'request_body' &&
          key != 'response_body' &&
          key != 'headers')
        key: value,
  };
  return crumb..data = cleaned;
}
