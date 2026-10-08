// Sentry for Edge Functions (ADR-008). Off unless the `SENTRY_DSN_EF` secret is set.
// No PII: no request bodies, headers, cookies or user emails — tag the user id only.
import * as Sentry from 'npm:@sentry/deno@10.75.3';

let enabled = false;

export function initSentry(functionName: string, dsn = Deno.env.get('SENTRY_DSN_EF')): boolean {
  if (enabled) return true;
  if (!dsn) return false;
  Sentry.init({
    dsn,
    environment: Deno.env.get('SENTRY_ENVIRONMENT') ?? 'staging',
    sendDefaultPii: false,
    tracesSampleRate: 0,
    // The edge runtime owns the global handlers; Supabase's guide turns these off.
    defaultIntegrations: false,
    beforeSend(event) {
      delete event.request;
      if (event.user) event.user = event.user.id ? { id: event.user.id } : undefined;
      return event;
    },
  });
  Sentry.setTag('function', functionName);
  enabled = true;
  return true;
}

/** Reports an unexpected failure. `context` holds route and error codes, never payloads or PII. */
export async function captureError(
  error: unknown,
  context: { route: string; userId?: string; code?: string },
): Promise<void> {
  if (!enabled) return;
  Sentry.withScope((scope) => {
    scope.setTag('route', context.route);
    if (context.code) scope.setTag('code', context.code);
    if (context.userId) scope.setUser({ id: context.userId });
    Sentry.captureException(error);
  });
  // Isolates can stop right after the response; flush so the event is not lost.
  await Sentry.flush(2000);
}
