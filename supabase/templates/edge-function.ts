// TEMPLATE (docs/16 §2) — copy to supabase/functions/<name>/index.ts, or add the route to the
// `api` function (docs/16 §8). Never deploy from supabase/templates/.
// Shape: Hono route → verify JWT → App Check (sensitive routes) → call a Postgres RPC as the user
//        → errors as { error: { code, message } } with codes from docs/07 §9.
// Sentry (ADR-008) reports unexpected failures. Business rules stay in Postgres (docs/16 §8).
import { type Context, Hono } from 'npm:hono@4.13.13';
import { createContextClient, verifyAuth } from 'npm:@supabase/server@1.9.1/core';
import { appCheckConfigFromEnv, appCheckGate } from '../functions/_shared/app_check.ts';
import { captureError, initSentry } from '../functions/_shared/sentry.ts';
// In supabase/functions/<name>/index.ts the imports are '../_shared/app_check.ts' and
// '../_shared/sentry.ts'.

initSentry('example-function');
const appCheck = appCheckConfigFromEnv();

// Mirror of docs/07 §9 — keep in sync.
const ERROR_CODES = [
  'not_authenticated', 'forbidden', 'invalid_input', 'not_enrolled', 'access_expired',
  'topic_locked', 'attempt_closed', 'deadline_passed', 'device_limit', 'device_revoked',
  'cooldown_active', 'pool_exhausted', 'rate_limited', 'payment_invalid', 'internal',
] as const;
type ErrorCode = (typeof ERROR_CODES)[number];

function isErrorCode(value: string): value is ErrorCode {
  return (ERROR_CODES as readonly string[]).includes(value);
}

function fail(c: Context, code: ErrorCode, message: string) {
  const status = code === 'not_authenticated' ? 401
    : code === 'forbidden' ? 403
    : code === 'internal' ? 500
    : 400;
  return c.json({ error: { code, message } }, status);
}

const app = new Hono().basePath('/example-function');

app.post('/example-route', async (c) => {
  const { data: auth, error: authError } = await verifyAuth(c.req.raw, { auth: 'user' });
  if (authError) return fail(c, 'not_authenticated', 'Sign in required.');

  // App Check (docs/16 §5) on sensitive routes only (video-otp, pdf-url, ai-tutor,
  // register-device). APP_CHECK_MODE=monitor logs and allows; enforce rejects.
  const gate = await appCheckGate(c.req.raw, 'example-route', appCheck);
  if (!gate.allow) return fail(c, 'forbidden', 'App verification failed.');

  const body = await c.req.json<{ courseId?: string }>().catch(() => null);
  if (!body?.courseId) return fail(c, 'invalid_input', 'courseId is required.');

  // Call as the user: auth.uid() and RLS apply inside the RPC.
  const supabase = createContextClient({ auth: { token: auth.token, keyName: auth.keyName } });
  const { data, error } = await supabase.rpc('example_rpc', { p_course_id: body.courseId });
  if (error) {
    if (isErrorCode(error.message)) return fail(c, error.message, error.message);
    // Log the Postgres error code only — never tokens, answer keys, payment data or PII.
    console.error('example-function/example-route rpc failed', error.code);
    await captureError(new Error(`rpc failed: ${error.code}`), { route: 'example-route', userId: auth.jwtClaims?.sub });
    return fail(c, 'internal', 'Something went wrong.');
  }
  return c.json(data);
});

export default { fetch: app.fetch };
